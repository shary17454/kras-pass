# QA scenarios

Two lists: what the automated suite proves on every run, and what still needs a
human. The second list is short by design — anything that could be automated
was.

```bash
godot --headless --path . tests/compile_check.tscn
godot --headless --fixed-fps 60 --path . tests/test_runner.tscn
```

A third tool sits between the two: the assertion suite proves a mini-game
*can* be completed, but says nothing about whether it plays well. The balance
simulator (`godot --headless --fixed-fps 60 --path . tools/balance_sim.tscn --
--runs=10`) plays every game many times with bots and reports tie rate,
spawn-slot bias, character bias, round length and Expert-vs-Easy separation to
`build/balance/report.html`. It has already found and driven the fix for three
real defects — recorded here because they are the kind of thing worth knowing
happened, not just that they are gone:

- **Quick Draw always tied (100%).** The signal timer was measured against
  `Time.get_ticks_msec()` — wall-clock time — while every AI reaction delay is
  a *simulated*-seconds budget. Under `--fixed-fps`, physics ticks run far
  faster than real time, so the in-round SIGNAL window elapsed in game-time
  long before enough wall-clock time had passed for any bot's reaction delay
  to fire. Fixed by accumulating `_signal_age` from `delta` inside `tick()`
  instead. (`generic_brain.gd`'s idle-circle heading had the same wall-clock
  habit — cosmetic, not scoring-relevant, but fixed for the same reason.)
- **Crate Relay always tied (100%), nobody ever delivered.** Two compounding
  bugs: (1) `courier_brain`'s "hold a few before banking" threshold (2–6,
  tuned for Star Rush's stack of up to 8) never triggers when a game caps
  carrying at 1, so a bot picks up a crate and immediately goes looking for
  another one instead of delivering — fixed by exposing
  `MiniGameController.max_carry()` and clamping the threshold to it. (2) The
  cross-shaped arena's dock positions were offset 45° from the actual floor
  geometry (a plus-sign has no collision on the diagonals), so a carrier
  walking toward its own dock fell through the world a few metres short,
  every time — fixed by aligning docks to the arm tips, matching what the
  arena-builder's own comment already claimed.
- **A fighter that falls in a non-eliminating game could get stuck forever**
  and never respawn — general, not specific to one game. `_queue_respawn()`
  teleports the fighter below `fall_y` and starts a countdown, but nothing
  marked it not-`alive` in the meantime, so `Fighter.on_fell_out()` fired
  again on the very next tick, re-entered `_queue_respawn()`, and reset the
  countdown back to `respawn_delay` — forever. This is what surfaced the
  Crate Relay dock bug as "100% ties" instead of "occasionally falls": once a
  carrier clipped the gap once, it was gone for the rest of the round.
- **A round that reached sudden death could report a negative duration.**
  `result.duration` was computed as `_round_duration() - ctx.time_left`, which
  assumes `time_left` counted down from the base round length — but entering
  `SUDDEN_DEATH` resets `time_left` to its own, larger budget
  (`sudden_death_seconds`, 30s), making the subtraction go negative. Fixed by
  tracking elapsed simulated time directly (`_round_elapsed`, incremented by
  `delta` every live tick) instead of deriving it from a budget that changes
  mid-round.

Remaining findings, still open — balance/tuning judgment calls rather than
code defects, so left for a human rather than guessed at:

- **Bumper Bowl ties ~80% of the time** with bots scoring nothing in most
  runs. By design, a bumper-hazard knockout credits nobody (`on_fighter_fell`
  in `bumper_bowl.gd` says so explicitly) — only a player-caused push scores.
  With five bumpers in a radius-13 bowl, most eliminations look environmental
  rather than player-driven, so the scoring loop the mini-game's own doc
  comment promises ("an aggressive, high-scoring game") rarely fires. Worth
  trying fewer bumpers or a stronger player-push incentive.
- **Crumble Court and Scrap Karts end in ~2–3 seconds** against the 14s
  target. Plausibly overtuned fall/ram aggression on default-difficulty bots
  rather than a bug — needs a human watching a round, not another simulation.
- **Symbol Echo ties ~80%.** May be inherent to four bots with correlated
  memory-error rates converging on the same sequence length; worth checking
  whether `echo_brain`'s per-step recall roll is varied enough between bots.
- Several games flag "spawn slot advantage" at the ~20–25% threshold with only
  8–12 sampled runs — at that sample size this is plausibly noise (binomial
  variance on a handful of wins per slot), not a real seat advantage. Re-run
  with `--runs=40+` before trusting it.

The same tool also runs a **mutator & chaos smoke pass**: one match per game
under a deliberately over-stuffed mutator set (`low_gravity`, `hyper_speed`,
`tiny`, `double_hazards`, `ice_floor`, `short_fuse` all at once — heavier than
any real preset, to stress `MutatorSystem`'s per-category compatibility
filtering) and one under chaos mode. This is not a balance measurement —
mutators are *meant* to skew things — the bar is just "completes, no new
console errors." Neither MutatorSystem nor chaos mode had been through the bot
tournament before they had a menu path to reach them (`data/mutators.json`'s
`presets` table). As of the run that added this pass, all 21 games completed
cleanly under both conditions.

---

## Covered automatically

### Every mini-game (all 21, every run)

`tests/suites/test_matches.gd` plays each game to completion with four AI
competitors and asserts:

- [x] The match starts, runs and produces a `MatchResult`
- [x] Every competitor is scored and ranked
- [x] At least one first place is awarded; places are all in `1..player_count`
- [x] Nothing is logged at ERROR level during the match
- [x] The AI competitors actually moved (not a frozen scene that "finished")
- [x] The camera never leaves the arena chasing a knocked-off player
- [x] The match ended on its own, before the safety timeout

### Match lifecycle

- [x] Multi-round match: three rounds played, match score is the sum of rounds
- [x] Pause: the clock stops, and resumes on unpause
- [x] Restart round: score resets, everyone is revived
- [x] Quit mid-match: teardown does not crash or leak into the next match
- [x] Controller lost mid-match: the match pauses with an explanation rather
      than leaving a human slot dead
- [x] Phase machine: illegal transitions are rejected (`PLAYING → COUNTDOWN`,
      `FINISH → PLAYING`, anything out of `DONE`)

### Scoring

- [x] Standard competition ranking with gaps (`5,5,3,1 → 1,1,3,4`)
- [x] Four-way draw reports as a draw with four winners
- [x] Race scoring inverts (lowest time wins); unfinished runners rank last
- [x] Multi-round aggregation sums scores and re-derives placement
- [x] Per-round detail counters merge into the match result
- [x] Survival scoring follows elimination order exactly
- [x] Tournament points 5/3/2/1; ties share the combined band
- [x] Tournament advances, completes and crowns the right champion
- [x] Random schedules are duplicate-free within a pool pass and seed-stable

### Save and progression

- [x] Write → read round trip preserves scalars, arrays and nested floats
- [x] A checksum mismatch is rejected and the backup is restored
- [x] A garbage save with no backup degrades to an empty profile, not a crash
- [x] Starter characters are available on a fresh profile
- [x] Trophy thresholds unlock the right characters
- [x] Unlocking something already unlocked is a silent no-op
- [x] First adventure clear pays exactly one trophy; replays pay none but do
      update the best score
- [x] Stars follow placement (3 / 2 / 1)
- [x] Completion percentage stays in `0..100` and rises as stages are cleared
- [x] Settings persist; unknown keys are rejected
- [x] Tutorial cards are one-shot

### Systems

- [x] Input frame press/hold/release edges
- [x] Input frames encode/decode losslessly enough for replay (5 bytes/player)
- [x] Virtual slots accept AI input and are not reported as human
- [x] Four AI profiles exist, strictly ordered by reaction time and accuracy,
      and none is superhuman
- [x] Every mini-game's AI script loads and extends `AIBrain`
- [x] Object pool reuses instances instead of allocating
- [x] Power-ups apply, refresh rather than stack, and expire back to baseline
- [x] A shield absorbs exactly one hit
- [x] Clearing effects between rounds leaves no residue
- [x] Expert AI out-scores Easy AI, measured with identical characters and
      mirrored slots

### Content and navigation

- [x] `Registry.validate()` is clean: no missing scripts, no dangling arena
      references, no unused arenas, no invalid player ranges, no adventure
      stage pointing at a game that does not exist
- [x] Content counts meet the shipping target (8 / 21 / 23 / 25 stages)
- [x] Every mini-game category has at least one game
- [x] No character has a larger stat budget than another (±0.15)
- [x] Arabic and English have identical key sets
- [x] Every character, game, arena, world, control hint and achievement string
      resolves in **both** locales
- [x] Every achievement condition type is implemented
- [x] Every registered screen builds without error and exposes a way back
- [x] The router's holder is live before the first navigation (regression: the
      boot screen used to land outside the tree)

---

## Needs a human

Genuinely not automatable here, or not worth the harness.

### Feel

- [ ] Does a knockout feel like it hit? Shake, hitstop, sound and knockback
      should land on the same frame
- [ ] Is 1.4 s the right respawn delay, or long enough to feel like a penalty?
- [ ] Do the four AI tiers *feel* different, or only measure differently?
- [ ] Is sudden death exciting or just fast?

### Four-player readability

- [ ] Can each of four people find their own character within half a second,
      mid-fight, on a TV across a room?
- [ ] Are the four colours distinguishable in each colour-blind mode?
- [ ] Is the HUD legible at 1080p from three metres?

### Devices

- [ ] Four physical gamepads connected, disconnected and reconnected mid-match
- [ ] Mixed input: two pads plus both keyboard profiles at once
- [ ] Join-in-progress on the Local Party screen with a pad that was plugged in
      after the screen opened
- [ ] Rumble strength on real hardware
- [ ] Xbox, PlayStation and generic pad button mappings

### Arabic build

- [ ] Every screen mirrored correctly, not merely translated
- [ ] No clipped or overflowing Arabic strings at 1.6× text scale
- [ ] Shaping and diacritics correct on Windows and iOS, not only macOS

### Long-session

- [ ] An hour of continuous play: memory stable, no frame-time drift
- [ ] Fifty consecutive matches without a restart
- [ ] Profile still loads after a hard kill mid-save (pull the power, do not
      quit cleanly)

### Platform

- [ ] Windows and Linux builds actually export and run
- [ ] Frame pacing on a 120 Hz display and on a 30 Hz cap
- [ ] Behaviour when the window loses focus mid-match
