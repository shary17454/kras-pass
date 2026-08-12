# QA scenarios

Two lists: what the automated suite proves on every run, and what still needs a
human. The second list is short by design — anything that could be automated
was.

```bash
godot --headless --path . tests/compile_check.tscn
godot --headless --fixed-fps 60 --path . tests/test_runner.tscn
```

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
