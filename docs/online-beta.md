# Online beta: protocol 1

## Implemented boundary

### Symbol Echo adapter preparation

`symbol_echo` now has a bounded presentation adapter and matching Node/Godot
world validators. It publishes the currently visible pad/step, public sequence
length, phase, progress, mistakes, finishers and monotonic feedback counters.
It does not put the answer sequence or hidden phase timer in snapshots. Guest
presentation discards its locally generated sequence and cannot score or tick
the host rules. This is payload minimization, not a cryptographic secrecy or
anti-cheat guarantee: the broader protocol still shares deterministic seeds.

The game remains excluded from the online room allowlists until real
multi-process ordinary/tournament matches and reconnect observations pass.
Adapter tests cover malformed/missing/extra fields, inconsistent finishers,
JSON round trips, repeated symbols, score/timer immutability and stale-audio
suppression. `/tmp/kras-echo-network.log`: 120 assertions passed. Server tests:
53 passed with local WebSocket listener permission; the sandbox-only attempt
failed at `listen EPERM` and is not counted as a passing transport run.
Full gate `kras-party-check.30MKH5`: 257 scripts compiled, 294 resources audited
with zero issues, 17,793 assertions passed, the three-lap race regression
passed and all 39 stability matches completed with zero failures. This is
desktop headless coverage, not iPhone performance or App Store approval.

The existing local match runtime remains authoritative on the host device.
The Node service authenticates **connection ownership**, not Apple accounts,
and controls room membership, readiness, loading barriers, slot assignment,
match epochs and access to snapshot/result publication. Guests cannot publish
another player's input or a result. The host is trusted: this is not a dedicated
anti-cheat simulation and is not suitable for ranked rewards.

Public discovery and six-character private codes use real WebSockets at
`/multiplayer`. Up to four people can join; empty places can be filled by host
AI. The lobby has character selection, readiness, host kick, arena, difficulty
and 1-10 rounds. Local input remains keyboard, gamepad or touch.

The development allowlist contains seventeen explicitly adapted rulesets; verification
limits for each are recorded below. These include `ring_rumble` on `vortex_ring`
/ `storm_ring`, without machine drops, random power-ups or bombs, and
`goal_guard` on `quad_court`. Offline Ring Rumble is unchanged. Goal Guard
replicates normal/heavy balls, launch generations and keeper charges; the guest
does not tick ball physics or evaluate goals. `gem_grab` uses `gem_hollow` /
`glass_terrace`, and `star_rush` uses `star_meadow`. Both share the bounded,
stable-ID collectible presenter; carried star counts come from the host too.
`zone_hold` on `dune_ring` replicates capture position, radius and ring color;
only the host advances capture progress or awards points.
`relic_hold` presents the loose relic or its carrier exclusively; pickup,
drop and held-time scoring remain host-only. Its configured arenas are
`star_meadow` and `gem_hollow`; see the verification limits below.
`tag_hunt` on `star_meadow` / `paint_grid` replicates the hunter and handover
grace; guests do not perform contact detection or free-time scoring.
`paint_grid` and `mnatiq` replicate all 169 tile owners on `paint_grid`;
capture, enclosed-region rewards and recounting remain host-only.
`mukharrib` adds the drone, warnings and sequenced scrub feedback on `paint_grid`.
`magnet_court` on `quad_court` adds charge, active timers and held-ball ownership
by ball slot, never by engine instance ID. Guests do not simulate attraction,
release, recharge or goals.
`storm_heart` on the same court adds turbine rotation, windup and volley timers,
two additional ball slots, and sequenced warning/volley feedback.
`sky_court` adds the selected engine, bank amount, warning/tilt timers and
sequenced feedback. Guests present the tilted surface without applying forces.
`crumble_court` replicates all 113 authored tiles: phase, warning/fall/respawn
timer, local height and monotonic collapse count. Guests never advance floor
physics or emit gameplay collapse signals; sound events are freshness-gated.
`blast_ball` on `ember_pit` replicates the explosive ball, fuse, launch identity
and sequenced explosion feedback. Elimination and rearming stay on the host.
`color_stand` on `color_floor` adds the 121-tile palette, called color, floor
states, phase timers and call/drop cues. Guests never choose a new color.
`quick_draw` on `draw_stage` adds visible prompt state and accepted responses,
without exposing the hidden wait countdown. Reaction latency is not compensated;
the local scripted test exhibits host advantage and is not a balance approval.
Optional random power-ups remain disabled in online beta configurations.
The other 22 games are not
online-enabled. The room service supports points/cups tournaments for
these supported arenas, with stable rosters, readiness between matches, seeded
no-repeat rotation, and server-owned cumulative accounting. Only the host can
advance the tournament. The configured points table is validated server-side.

Final ties run short contender-only matches. Other players retain their slots
as spectators. At most three tie-breaks are allowed; persistent ties produce
shared champions, not an arbitrary slot-based winner. Cup tournaments also
have a bounded regular-round limit. These are limited beta tournaments, not
39-game online tournaments.

Clients render host snapshots at 20 Hz with smoothing; they send input at
30 Hz. The host simulates at the engine physics frequency. Remote clients do
not evaluate scores, winners, collisions or timers. Snapshots include fighter
pose/velocity/status, shrinking radius, phase, round, countdown and scores.
Results travel once through the server after host completion. Online results
do not grant local progression or create misleading input-only replays.

## Recovery and bounded resources

- A cryptographically random bearer resume token is sent only to its owner.
  It is kept in memory, never logged, included in room discovery, or saved.
- The reconnect grace is 30 seconds. Slot/character/score identity survives a
  transport reconnect in the same running app. Stale inputs become neutral
  after 250 ms; this beta does not silently replace disconnected people by AI.
- A still-active old connection returns `session_active`; the client retries
  while the server heartbeat detects the dead connection.
- No host migration. A host loss pauses authoritative updates; expiry closes
  the room without fabricating a winner. Guest expiry during a match also
  aborts this beta rather than changing roster/scoring under the players.
- Loading has a 60-second timeout. Missing host snapshots have a 30-second
  watchdog. Idle rooms expire after 30 minutes.
- Limits: 200 rooms, 800 connections, 16 connections per socket IP, 64 KiB
  packets, 48 KiB snapshots, 90 messages/s, 12 control messages/s, 256 KiB
  outbound backlog. No compression and no arbitrary Godot object decoding.
- Browser Origins are denied unless explicitly allowlisted. Native clients
  omit Origin. Production clients require WSS; WS is loopback-only.

## Local verification

```sh
cd server
npm ci --ignore-scripts
npm test
node network-smoke.js
node network-smoke.js --tournament
cd ..
sh tools/check_party.sh
```

`network-smoke.js` starts an ephemeral loopback service and real isolated Godot
processes: two humans plus two bots, then four humans. Each runs two shortened
rounds, disconnects/reconnects one client, checks host receipt of remote input,
snapshot reception and identical results. It prints its evidence directory.
The tournament option also exercises repeated scene cleanup/loading, arena
rotation, next-round readiness and identical final standings on all peers.
This is a networking smoke test, not proof of Internet latency, phone thermal
behavior, game balance or visual/audio parity.

## Railway deployment gate

The account service and SQLite storage are preserved. Multiplayer is **off by
default**. Do not enable production just because the loopback tests pass.

1. Deploy the reviewed feature commit to a separate Railway staging service
   using the existing Dockerfile. Preserve account variables and `/data` volume
   if sharing an account-service instance. Never copy secrets into Git.
2. Set `MULTIPLAYER_ENABLED=true`. For native clients no Origin list is needed;
   set `MULTIPLAYER_ORIGINS` only to exact trusted browser origins if web export
   is used. Configure one replica: rooms live in process memory, not SQLite.
3. Verify `/health` and WebSocket upgrade to `wss://<staging-domain>/multiplayer`.
4. Run the client with `KRAS_MULTIPLAYER_URL` for desktop QA, or set the Godot
   project setting `kras/online/endpoint` in a staging export. The default
   shipping project has no enabled endpoint.
5. Test four physical devices, Wi-Fi/cellular transitions, backgrounding,
   high latency, packet loss, portrait/landscape and long sessions.
6. Only then enable a production endpoint in a reviewed build. Shutdown/redeploy
   closes active rooms explicitly; it cannot resume a simulation after a server
   or host process restart. Rollback: disable the endpoint/feature flag; local
   gameplay and Apple authentication remain available.

No Railway deployment, App Store upload, or review submission is implied by
these changes. Use actual deployment evidence to update that status.

## Verification record (2026-09-30)

- Node account + room tests: 11 passing, including four real WebSocket clients,
  malformed/unauthorized packets, reconnect identity, load timeout and host
  snapshot watchdog. Dependency install audit reported no vulnerabilities.
- Godot network unit suite: 17 assertions passed (snapshot validation, slot
  ownership, stale-input expiry and session cleanup).
- Final compile check: all 222 GDScript files compiled successfully; evidence
  `/tmp/kras-network-final-compile.log`. This does not replace runtime tests.
- An initial real-engine run passed two-human/two-bot and four-human sessions,
  two rounds each, with identical results and a guest reconnect:
  `/tmp`/macOS temporary directory `kras-network-smoke-A72oxL`.
- Subsequent runs were not reliably repeatable: connection expiry and process
  timeouts occurred while multiple Godot engines were running. The client now
  logs close codes, and the server heartbeat respects the scene-loading budget.
  One later run (`kras-network-smoke-swdSvl`) timed out before the two-player
  room started. These load-sensitive failures are retained as QA evidence.
- The final isolated run on the current code (`kras-network-smoke-JRi1Of`)
  passed both two-human/two-bot and four-human sessions. Every human moved,
  results matched across devices, and peer 2 reconnected in both sessions.
  Guests received 648-668 snapshots. This is loopback verification, not a
  guarantee under network loss, device suspension or heavy resource pressure.
- The full local regression run `kras-party-check.JYuHn9` passed compilation
  and content inventory but was stopped after prolonged integration execution;
  it has **no final passing result**. Re-run on an unloaded test host.
- A subsequent standalone lifecycle run completed **39 matches, 0 failures**
  with four AI players, shortened timed rounds and normal race laps. It checks
  result validity, cleanup, retained objects, input and global signal ownership.
  Evidence: `/tmp/kras-network-final-stability.log` and
  `/tmp/kras-network-final-stability-save/stability.json`. One cycle does not
  establish long-session memory stability or physical-device performance.
- Arabic lobby fixture screenshots were inspected in landscape and portrait;
  these are presentation fixtures, not evidence of device/network performance.

The follow-up below completes full local regression and adds multi-engine
checks. The release gate still requires staging deployment and physical-device
and Internet QA. General 39-game
online support and networked tournament rotation are still future work.

## Release preparation follow-up (2026-10-02 session)

Work is isolated on `feature/kras-online-release`, based on main commit
`9135a741c474371c347db7a1c6759efc2f39d28e`. Untracked duplicate files ending in
` 2` in the original checkout were not deleted or included.

Implemented and regression-tested:

- Reuse vacant lobby slots without assigning two participants the same slot.
- Clear old results on lobby return; do not replay them on lobby reconnect.
- Give a disconnected host the full reconnect grace independently of its last
  snapshot's age, while retaining the connected-host authority watchdog.
- Apply a result once per match epoch; clear remote input at match boundaries.
- Retain a pending host result in memory until acknowledged, and retry only
  after the server confirms that the same epoch is still playing.
- Track generated Godot script UIDs. Ignore release screenshots/source artwork
  and generated iOS resources during Godot import without removing those files.

Verification:

- Node: 14 passing tests. The three new server regressions failed before the
  repair and passed afterwards. Dependency audit: zero reported vulnerabilities.
- Full `tools/check_party.sh` passed on the slot/reconnect/idempotency changes:
  222 scripts compile, inventory has zero issues, 12,423 assertions pass,
  independent race regression passes, 39 lifecycle matches have zero failures.
  Evidence: `kras-party-check.55Plas` under the host temporary directory.
- Real two- and four-human Godot sessions passed with movement, equal results
  and guest reconnect: `kras-network-smoke-NCgcT9`.
- The subsequent pending-result delivery change passed the focused network
  suite (27 assertions) and another 222-script compile check. Logs:
  `/tmp/kras-reconnect-tests.log`, `/tmp/kras-resume-final-compile.log`.
- A second real-engine run deliberately dropped the host's first result packet
  by closing its transport. Both two- and four-human sessions completed with
  identical results, host reconnect and guest reconnect. Evidence:
  `kras-network-smoke-f35E6w`. This verifies the pending-result delivery path.
- The native bridge build script now honors DEVELOPER_DIR and rejects a tools
  directory without the full Xcode toolchain. Shell syntax was checked; this
  is preparation only, not an archive or a native bridge build result.
- Sandboxed Godot emitted a macOS CA lookup warning; initial editor import also
  could not save global editor preferences. These are not successful device
  signing or network-authentication tests.

Live read-only release checks:

- Apple app 6801506973 is `com.shary.kraspass`; version 1.1.10 is READY_FOR_SALE.
  Build 107 is the most recently uploaded entry returned, while build 108 also
  already exists. Do not reuse either number or infer archive source from them.
- Existing distribution identity for team 4HM66AD594 is accessible in Keychain.
  Xcode 27.0 (27A266a) and a connected physical iPhone were detected. No P12 was
  imported and no certificate was changed.
- Railway source is shary17454/kras-pass, production/main, but its observed
  successful deployment is still c61005fd33e3821323379b56d9cfedd4a7407ce0.
  Required Apple variables are present, client/team match, SQLite uses /data,
  health is OK, and unauthenticated /account returns 401. Multiplayer is off.
  The last-24-hours error-log query returned no error entries. These checks do
  not prove a signed-device login, database migration, or a new deployment.

No new Apple archive/upload/submission or Railway deploy is established by
this follow-up. The 38 remaining online adapters,
Internet/device QA and the production feature-enable gate remain outstanding.

## Tournament follow-up verification

- Server tests: 21 passed, including cup targets, shared ties, contender-only
  scoring, reconnect standings, invalid configuration and duplicate results.
- Focused Godot network tests: 36 assertions passed. Contender IDs are tested
  through JSON decoding, not only integer-valued local fixtures.
- Actual Godot tournaments passed with two humans plus two bots and with four
  humans: six matches each (three regular plus three tied finals), matching
  standings on every peer, movement every active round, and both host-result
  loss and guest reconnect. Evidence: `kras-network-smoke-GycbbH` under the
  macOS temporary directory. Initial failed runs exposed late input/snapshot
  publication and JSON numeric-type contender matching; those were fixed.
- The successful tournament run still logged duplicate `leave/not_joined`
  during simultaneous cleanup. Leave is now idempotent; server regression
  tests cover that final adjustment. This did not change tournament scoring.
- Renderer QA captured lobby and final standings in portrait and landscape.
  It caught a nested-scroll collapse hiding the portrait round table. The
  inner scroll is removed, and the fixture now checks four visible-sized rows.
  Log: `/tmp/kras-tournament-ui-final.log`; screenshots:
  `/tmp/kras-online-results-1080x1920.png` and
  `/tmp/kras-online-results-1920x1080.png` (plus lobby equivalents).
- These tests use loopback on macOS, not Internet matchmaking or an iPhone.
  No claim of 39 online-ready games, phone performance, or release readiness
  follows from them. No production enablement or Apple submission was made.
- Full regression attempt `kras-party-check.0CNKEb`: compile (222 scripts)
  and inventory passed, but the integration suite became abnormally slow and
  was stopped after more than 25 minutes without recent log progress. It is
  **incomplete, not passed**. No assertion failure had been reported before
  termination; that does not establish correctness. The process sample is
  `/tmp/kras-party-stall.sample` (about 886 MB footprint, stripped native
  symbols, insufficient to identify a root cause). TestHarness now prints
  each test start to make the next isolated reproduction attributable.
- The separate stability run completed all 39 default-arena matches with zero
  failures after that interrupted full-suite attempt. Evidence:
  `/tmp/kras-tournament-stability.log` and
  `/tmp/kras-tournament-stability-save/stability.json`. This is one cycle with
  four AI and shortened timed rounds, not comprehensive multiplayer/device QA
  or a long-duration memory-leak certification.
- Final ordinary-match compatibility retests did **not** pass:
  `kras-network-smoke-bWHju8` closed on authority timeout, and
  `kras-network-smoke-p4gbw1` expired the session during transport recovery.
  Neither run reached a completed result. They coincided with unusually slow
  local command execution, but the cause is not established. Do not dismiss
  them as environmental or widen watchdogs to turn the test green. Reproduce
  with host tick/transport timing on a responsive machine before merging or
  releasing. Earlier successful tournament results do not override this gate.

## Timing diagnosis follow-up

The next ordinary-match run, `kras-network-smoke-X5hkJc`, passed both two-human
and four-human sessions, including guest reconnect and lost host result
recovery. Scores matched on all peers. No production timeout was increased.
The new diagnostics measured a maximum server event-loop delay of 11,778 ms;
initial host scene loading also caused a roughly 10-second frame gap. This is
evidence of scheduling/load sensitivity, not proof that the prior failures
were exclusively environmental. Retain the failed-run evidence and require
repeatable CI and device testing before clearing the release gate.

The smoke harness now records bounded timing/state diagnostics without resume
tokens or credentials. Godot logs report epoch, phase, maximum frame gap and
snapshot count; the server reports loading/result transitions and event-loop
delay. This distinguishes a paused host from a stalled service in future runs.

## CI verification on 2026-10-02

GitHub Actions run [36954750408](https://github.com/shary17454/kras-pass/actions/runs/36954750408)
completed successfully for source `a5aad59d1f270a41d0eb722d78a30e676ef0ff28`:

- Ordinary real-engine sessions passed with two humans plus bots and four humans.
- Tournament sessions passed six matches per configuration, including reconnect,
  lost-result recovery, tied standings and bounded sudden-death rounds.
- The full Godot suite passed 12,438 assertions.
- Three stability cycles completed 117 matches with zero failures.
- Wrapper checks passed their success path and ten injected failure cases.

This clears the repeatable Linux CI check for that exact source, not native
iPhone performance or all-game online compatibility. It does not cover subsequent
monotonic-clock or snapshot-validation changes until those are tested separately.
The earlier failed local runs remain diagnostic evidence above.

The follow-up monotonic-deadline change passed all 22 server tests. Client
snapshot bounds passed 52 focused assertions using
`/tmp/kras-snapshot-validation-final.log`, including malformed scalar values,
unsupported roster sizes, last-valid-state preservation, and JSON numeric
round trips. macOS sandbox CA-certificate lookup reported its environment error;
the focused suite itself exited zero. Follow-up CI run
[36956121783](https://github.com/shary17454/kras-pass/actions/runs/36956121783)
passed for `e17f5eec4f59095cf1ded01e3227f6fcbd54be8d`: 12,454 assertions and
117 stability matches with zero failures, plus the real-network scenarios.
That run predates the Goal Guard adapter below.

## Goal Guard adapter verification

- `/tmp/kras-goal-replica-final2.log`: 120 focused assertions passed, including
  JSON validation, normal/heavy appearance, launch teleportation, round reset,
  spectator scores, and no guest ball simulation or scoring.
- `/tmp/kras-goal-compile.log`: all 223 scripts compiled.
- Server tests: 25 passed, including game-specific world validation and a
  tournament whose current game differs from the lobby default.
- `kras-network-smoke-65T0fU`: ordinary two-human/bot and four-human matches
  passed, with reconnect and lost host-result recovery. This used short rounds.
- `kras-network-smoke-OHeS55`: three-match tournaments passed for both player
  configurations using 15-second rounds. Each guest received more than 1,600
  world snapshots; ball presentation and final scores/standings agreed.
  Neither random tournament required a tie-break; spectator scoring is covered
  by the focused fixture, not claimed as a real-network tie-break result.
- `/tmp/kras-goal-online-ui.log`: rendered Arabic lobby/results fixtures passed
  at 1080x1920 and 1920x1080. Captures were visually inspected. These are desktop
  fixtures, not iPhone performance tests.

The CI workflow now repeats both ordinary and tournament Goal Guard scenarios.
Production deployment, real-device latency/audio QA and the remaining world
adapters are still outstanding. Guest collision/goal sound events are not yet
replicated; phase/countdown cues are shared by the existing match adapter.

## Collection adapters and resource cleanup verification

Gem Grab and Star Rush now share a visual-only collectible replica. The host
owns pickup, deposit and scoring; guests reconcile bounded stable item IDs and
carried-item counts. Unknown kinds, duplicate IDs, non-finite transforms and
oversized payloads are rejected before updating visible state.

- `/tmp/kras-collection-replica-limit.log`: 64 assertions passed, including
  worst-case snapshot size, JSON round trips, pool reuse and no guest physics.
- Server tests: 27 passed.
- `kras-network-smoke-YGtgxV`: Gem Grab three-match tournaments passed with
  two humans/two bots and four humans, reconnect and lost-result recovery.
- `kras-network-smoke-YmbjnX`: the same Star Rush configurations passed;
  every peer observed carrying and positive collection scores. Neither run
  needed a tie-break. These are localhost tests, not production latency tests.
- `/tmp/kras-collection-online-ui-clean.log`: portrait and landscape Arabic
  lobby fixtures rendered and were visually inspected. Audio shutdown now
  stops voices/tweens and releases cached streams; no exit leak was reported.
- `/tmp/kras-audio-shutdown-clean.log`: 248 system assertions passed without
  leak warnings after draining the isolated power-up fixture pool.
- The preceding source `c49505b57c325facd4eed9b897e207e8f26520de` passed
  [CI 36957648373](https://github.com/shary17454/kras-pass/actions/runs/36957648373).
  This is not evidence for the later collection changes. The new CI matrix
  separately checks core quality and each of the four online adapters.

Production remains disabled. Other minigames still need world adapters, and
guest pickup/deposit sound events and physical-device QA remain outstanding.
No iOS archive, upload or App Review submission is represented by these tests.

## Local capture-zone lifecycle regression

Zone Hold now scales its visible capture marker when sudden death shrinks the
scoring radius, and restores both at round start. Fractional capture points are
cleared between rounds. Unchanged ownership no longer reassigns the cached ring
material every tick. `/tmp/kras-zone-hold.log` passed 15 assertions covering
contested scoring, visual/rule agreement and repeatable round reset. That
lifecycle fix preceded the network adapter below. `/tmp/kras-zone-replay.log` also
passed 71 replay assertions, including an actual Zone Hold recording/playback
with matching scores and placements.

## Capture-zone network verification

- `/tmp/kras-zone-network-unit.log`: 35 assertions passed, including visual
  radius/ownership updates, invalid snapshot rejection and no guest scoring.
- `/tmp/kras-zone-network-compile.log`: 227 scripts compiled after fixing an
  inferred-type error in the new network test's steering fixture. The first
  network attempt (`kras-network-smoke-duYKIf`) failed before starting a match
  and is not counted as passing evidence.
- Server tests: 29 passed, including authoritative capture-world validation.
- `kras-network-smoke-wLRJs3`: ordinary two-round matches passed for two
  humans/two bots and four humans, including guest reconnect and lost-host-result
  recovery. Scores agreed: `[9,0,0,3]` and `[17,0,0,0]` respectively. Guests
  received over 1,000 world snapshots and checked capture presentation against
  authority. Steering is deliberately arranged to exercise capture scoring,
  not a character or spawn balance benchmark.
- `kras-network-smoke-paEdK1`: three-match Zone Hold tournaments passed for
  two humans/two bots and four humans. All peers agreed on the final points
  `[12,6,9,6]` and `[15,6,6,6]`, with champion slot 0. Guests received more
  than 1,600 world snapshots. Neither tournament required a tie-break. Late
  in-flight input after room closure was rejected as `not_joined`; no results
  were changed. These runs are not physical-device performance evidence.
- CI now includes ordinary and tournament Zone Hold scenarios. Device rendering
  and production-network QA remain unverified for this adapter.

## Completed collection CI baseline

[CI 36959389790](https://github.com/shary17454/kras-pass/actions/runs/36959389790)
completed successfully for `ba4d218dfe86962ee26d68bdbf7e2ba746824275`: all five
jobs passed, including ordinary/tournament networking for the four adapters at
that commit. Core quality recorded 225 scripts, 12,570 assertions and 117
stability matches with zero failures. This baseline predates the Zone Hold
adapter and subsequent Relic Hold lifecycle fix; those need their own CI run.

## Relic Hold round reset

The previous relic carrier now regains the game's configured attack permission
when a round starts or the controller cleans up. Carrying and fractional score
are cleared; repeated callbacks do not duplicate the relic. Dropping also uses
the declared attack permission rather than forcing attacks on unconditionally.
`/tmp/kras-relic-round-reset.log` passed 15 assertions without resource-leak
warnings. That lifecycle fix preceded the network adapter below.

## Relic Hold network verification

- `/tmp/kras-relic-replica-unit.log`: 45 assertions passed for loose/held state,
  malformed ownership, drop, respawn delay, no guest colliders/scoring, and
  stable visual reuse.
- `/tmp/kras-relic-replica-compile.log`: 229 scripts compiled.
- Server tests: 31 passed after integrating room-level relic validation.
  Four world-validator tests also passed after rejecting fractional roster sizes.
- `kras-network-smoke-m0vrgW`: two-round matches on `star_meadow` passed with
  two humans/two bots and four humans, including reconnect and dropped-result
  recovery. All peers agreed on `[28,0,0,4]` and `[34,0,0,0]`; guests received
  over 1,000 snapshots and checked holder, carrying and loose-item presentation.
- `/tmp/kras-relic-visual.log`: 49 graphical assertions passed, with no leak
  warnings. `/tmp/kras-relic-carrier.png` was visually inspected: the marker
  follows the carrier and the HUD identifies it. This was desktop OpenGL
  compatibility rendering, not physical iPhone or iPad QA.
- `kras-network-smoke-FAZK7M`: three-match relic tournaments passed for two
  humans/two bots and four humans, using both `gem_hollow` and `star_meadow`.
  Final points agreed across peers: `[12,6,7,10]` (champion 0) and `[9,6,12,6]`
  (champion 2). Guests received more than 1,600 snapshots. No tie-break occurred.
  The local server measured a maximum event-loop delay of 14,554 ms during this
  run. This is a functional pass, not latency/performance acceptance; the stall
  cause and physical-device performance remain unresolved.
- The new CI scenario covers ordinary matches and tournaments. Mobile rendering
  and production latency remain unverified. Production online remains disabled.

## Tag Hunt adapter and room integration

The shared replica can now present the hunter role and handover grace without
contact detection or scoring. Repeated snapshots cannot compound the role's
speed bonus, and clearing the role restores the original speed and marker.
`/tmp/kras-tag-replica-unit.log` passed 26 assertions; all five server world-state
validator tests also passed before room integration.

- Room-level validation now requires a valid hunter world. Server tests: 33
  passed. `/tmp/kras-tag-room-compile.log`: 231 scripts compiled.
- `kras-network-smoke-LfHts1`: two-round matches passed for two humans/two bots
  and four humans on `star_meadow`, with reconnect and dropped-result recovery.
  All peers observed an in-round hunter handover and agreed on `[36,36,10,16]`
  and `[34,38,10,13]`. Guests checked the hunter and grace against the latest
  authoritative snapshot and received over 1,000 world snapshots. This is not
  a balance benchmark; the fixture deliberately brings players together.
- `/tmp/kras-tag-visual.log`: 30 graphical assertions passed without leak
  warnings. `/tmp/kras-tag-hunter.png` was visually inspected for the marker
  and hunter HUD. This is desktop OpenGL compatibility rendering, not iOS QA.
- The CI matrix includes ordinary and tournament Tag Hunt scenarios. Its
  tournament, second arena and physical-device/network performance still need
  verification. Production online remains disabled.

## Completed five-adapter CI baseline

[CI 36960797391](https://github.com/shary17454/kras-pass/actions/runs/36960797391)
passed all six jobs for `63b10c626bfc3a832d07fa7a9db3804173bb9e74`, including
Zone Hold ordinary matches and tournaments. Core quality recorded 228 scripts,
12,618 assertions and 117 stability matches with zero failures. That source
predates the relic/tag network adapters; their results must be tracked separately.

## Paint-family reset and prepared ownership adapter

`ArenaTile.claim()` now changes the visible owner material without overwriting
the neutral floor color. This fixes old player colors remaining after a round
reset or Mukharrib scrub. `/tmp/kras-paint-reset.log` passed 34 assertions across
Paint Grid, Mnatiq and Mukharrib, including score reset and scrub visuals.

The prepared shared adapter for `paint_grid` and `mnatiq` sends 169 ownership
slots indexed by the authored tile coordinates. It does not send arbitrary
materials or run guest capture/recount logic. Tests check every coordinate
against the fixed protocol layout, so an arena size change requires an explicit
adapter update. `/tmp/kras-paint-replica-final.log` passed 722 assertions. All
six server world-validator tests passed. Development room routing now includes
both games; this does not enable production online play. Mukharrib
also needs its drone and warning-state adapter; tile ownership alone is not
sufficient to enable that game online.

- `/tmp/kras-paint-room-compile.log`: all 234 scripts compile.
- Server suite: 35 tests passed, including both paint rulesets rejecting missing,
  undersized, oversized, fractional and out-of-roster ownership updates.
- `kras-network-smoke-dEbU8k`: Paint Grid two-human/two-bot and four-human
  matches passed, including transport recovery, tile-owner comparison and final
  score agreement. Guests received 1087-1107 world snapshots. The test logged
  late `not_joined` input rejections after room closure, not during gameplay.
  Its server event-loop maximum was 3173 ms and initial loading frame gaps were
  about 36 seconds. This is functional evidence, not performance acceptance.
- `kras-network-smoke-PbVgDu`: Mnatiq two-human/two-bot and four-human matches
  passed with ownership, reconnect and score agreement. Guests received
  1087-1107 snapshots; server event-loop maximum was 2322 ms. This is also
  functional evidence only; the post-close input rejections occurred again.
- `/tmp/kras-paint-visual-final.log`: 726 assertions passed with the desktop
  compatibility renderer. Both `/tmp/kras-paint-guest-paint_grid.png` and
  `/tmp/kras-paint-guest-mnatiq.png` were inspected at 1280x720: roster colors
  reach the tile materials. These synthetic ownership fixtures are not complete
  gameplay, portrait-layout or iPhone QA. The first capture attempt failed on
  a test variable's inferred type; an explicit String fixed it before this run.
- `kras-network-smoke-e6T2ZW`: Paint Grid three-match tournaments passed with
  two humans/two bots and four humans. Identity, tile ownership and final
  standings agreed after reconnect; guests received 1661-1684 snapshots.
  A tied ordinary round shared awards correctly, but neither final standing
  required a sudden-death match. Server event-loop maximum was 1784 ms.
- `kras-network-smoke-g3Xzyy`: Mnatiq three-match tournaments passed with two
  humans/two bots and four humans. Final points/cups/champions agreed across all
  peers after reconnect; guests received 1664-1684 snapshots. Neither final
  required sudden death. Server event-loop maximum was 1835 ms; device latency
  and performance acceptance remain outstanding.

## Saboteur world adapter and event replay protection

`saboteur_replica.gd` combines fixed-grid ownership with bounded drone position,
rotor angle, target tile and warning/cycle timers. The guest renders the host's
warning cells without running target choice, scrub, damage or point logic.
Repeated snapshots reuse warning meshes; clearing/changing targets removes the
old warning. Both development room allowlists now include this game; production
online play remains disabled.

- `/tmp/kras-saboteur-unit.log`: 211 assertions passed, covering JSON capture,
  malformed/missing fields, last-valid-state retention, warning cells at centre
  and corner, no guest timer advancement or scrub, and host-driven clear/reset.
- All seven server world-validator tests passed.
- `/tmp/kras-saboteur-compile.log`: all 236 scripts compiled.
- `/tmp/kras-saboteur-visual-clean.log`: 212 graphical assertions passed.
  `/tmp/kras-saboteur-warning.png` was inspected: the drone and nine white
  warning tiles render above host-owned colors. This is a desktop fixture,
  not a device performance or full-layout acceptance test.
- The first graphical run leaked an AudioStreamWAV and its playback while
  quitting during a music fade. The shared test runner now explicitly shuts
  audio down and waits two frames before exit; the rerun has no leak warning.
- Import generated the new script UIDs. The sandbox reported inability to save
  the user's editor settings and read system CA certificates; these are not
  treated as product errors or proof of successful release building.
- Host warning/scrub sequences now survive round changes. Guest presentation
  consumes each new event once, and suppresses historical effects on first
  snapshot, round change or after a snapshot gap longer than one second.
  The controller exposes visual/audio scrub feedback separately from damage,
  tile ownership and scoring; guest feedback never applies those rules.
- `/tmp/kras-saboteur-events-unit.log`: 236 assertions passed, including repeated
  snapshots, reconnect gaps, first snapshots and monotonic host event capture.
- `/tmp/kras-saboteur-events-visual.log`: 240 assertions passed with actual
  pooled sound triggers and no leak warning. The capture is a test fixture.
- `/tmp/kras-saboteur-room-compile.log`: all 236 scripts compile; 36 server tests
  passed, including room rejection of ownership-only Saboteur packets.
- `kras-network-smoke-kVJ1mS`: ordinary Saboteur matches passed with two
  humans/two bots and four humans. The fixture requires an observed warning and
  scrub, compares drone/target/tile presentation against the final host snapshot,
  and verifies reconnect and identical scores. Guests received 1088-1107 world
  snapshots. Server event-loop maximum was 51 ms in this run, not an iOS FPS or
  network-latency certification.
- Saboteur's tournament run and device QA remain required; the CI matrix now
  includes ordinary/tournament scenarios for all ten development rulesets.

## Completed seven-game CI baseline

GitHub Actions run `36962406988`, source
`ea0653a1de827d1ef8e07c52b094ceaf187c0197`, completed all eight matrix jobs
successfully. Its core job `110698736499` compiled 231 scripts, passed 12,673
assertions, and completed 117 stability matches with zero failures. The other
jobs cover ordinary/tournament networking for the seven rulesets through Tag
Hunt. This is not evidence for the later paint or Saboteur commits or a release.

The newer run `36965027879`, source
`b80576dc01db01c380ddb3a105434d342eba6e7b`, has a successful core job
`110706801891`: 236 scripts, 13,662 assertions, and 117 stability matches with
zero failures. All eleven jobs completed successfully.
This core result covers paint and Saboteur, but predates the Magnet changes.
The matrix includes all ten rulesets' ordinary and tournament network checks.
A new run `36967949347`
uses source `94a5222dc333e0343f2582515fda27b9d8c5e12f` and includes Magnet and
Storm; it was verified queued, not completed. Neither run covers Sky changes.

## Magnet Court adapter and capture physics

The shared Goal Guard ball presenter is extended with bounded per-player magnet
meters and one owner per ball slot. Both room admission and guest validation
require the complete ball and magnet state. Reset/release reconstruct ownership
using guest-local ball IDs, without transferring engine identities.

Local gameplay also needed correction: the ordinary shield intercepted frontal
shots before magnet capture, and ball tick normalization restored speed while
the ball was held. The overridable shared ball-tick hook now catches swept paths
before shield interception and parks captured balls until release. Elimination
releases held balls and disables the magnet. Tests cover 30/60/120 Hz steps;
these are simulation tests, not measured device frame rates.

Magnet Court uses keeper controls instead of an unused second aiming stick.
Its dash and ability hit regions are tested at portrait and landscape sizes.

- `/tmp/kras-magnet-physics-release.log`: 175 assertions passed before the
  additional control-layout checks; Goal Guard regression passed 120 assertions
  in `/tmp/kras-magnet-goal-regression.log`.
- `/tmp/kras-magnet-visual-drawn.log`: 191 assertions passed, including capture
  to `/tmp/kras-magnet-held.png`. Earlier graphical fixtures produced six GL
  texture warnings on exit. Clearing the shared texture cache did not fix them
  and was reverted. Waiting for a rendered frame before disposing each fixture
  removed those warnings in the rerun. This is not a long-session memory test.
- `/tmp/kras-magnet-room-compile.log`: 238 scripts compiled. All 38 Node tests
  passed with loopback access; the sandbox-only attempt failed specifically
  with `listen EPERM` and is not counted as a successful integration run.
- Final compilation passed all 238 scripts in
  `/tmp/kras-magnet-final-compile-local.log`. The full local suite passed 13,779
  assertions in `/tmp/kras-magnet-full-tests.log`, with isolated save data.
  The quality wrapper now rejects GL texture-leak messages even on exit code
  zero; `tests/check_party_wrapper.sh` passed its success path and eleven
  failure cases (`kras-wrapper-test.TU6gfe`).
- `kras-network-smoke-wwrRq4`: ordinary matches passed with two humans/two bots
  and four humans, observed actual capture, verified reconnect/results and
  compared held-ball ownership and meters on guests. Guests received 1088-1107
  snapshots. The maximum server event-loop delay was 55 ms in that run, not an
  iPhone or Internet performance certification.
- `kras-network-smoke-LwbxqJ`: three-match points tournaments passed for both
  two humans/two bots and four humans. All peers agreed on standings and the
  champion after host/guest reconnect. Final points were `[9,13,6,6]` and
  `[7,10,9,9]`; no final sudden death was needed in these runs. Guests received
  1665-1684 snapshots, and the server event-loop maximum was 40 ms.
- Device QA and guest ability sound-event parity remain pending. Production
  online play is still disabled.

## Storm Heart turbine replication

The turbine presenter extends the shared ball state with bounded rotation,
warning/volley timers and monotonic event counters. Only this ruleset accepts
up to two extra balls beyond the player count; ordinary Goal Guard and Magnet
retain their original limits. The host still creates and launches all balls.
Guest effects cannot score, launch or spawn anything. Repeated snapshots,
first snapshots, round changes and reconnect gaps cannot replay old sounds.
The controller separates presentation from authoritative volley rules and
resets turbine rotation between rounds. Keeper controls remove an unused
second stick without removing attack or dash.

- `/tmp/kras-storm-unit.log`: 163 assertions passed for two-, three- and
  four-player state, bounds, extra balls, reset, events and host-only rules.
- `/tmp/kras-storm-events-final.log`: 185 graphical assertions passed, including
  pooled sounds, keeper controls and suppression across pause/resume.
  `/tmp/kras-storm-final.png` was inspected:
  the turbine, post-launch normal/heavy balls and four keepers are visible.
  This desktop fixture is not device performance or complete gameplay QA.
- `/tmp/kras-storm-import.log`: asset/class import completed;
  `/tmp/kras-storm-compile.log`: all 240 scripts compiled.
- All 40 server tests passed, including real WebSockets and room-level
  rejection of missing turbine state and excessive ball counts.
- `kras-network-smoke-x6ZN4N`: ordinary matches passed with two humans/two bots
  and four humans. All clients observed warning and volley, compared turbine
  state/balls with the host, and agreed on results after reconnect. Guests
  received 1088-1107 snapshots; the server event-loop maximum was 62 ms.
- `kras-network-smoke-lVEZ4U`: three-match points tournaments passed with two
  humans/two bots and four humans, including host/guest reconnect and identical
  final standings. Final points were `[7,4,12,11]` and `[7,13,9,5]`; neither run
  required final sudden death. Guests received 1665-1684 snapshots; the server
  event-loop maximum was 38 ms. Neither network run is an iOS performance test.
- `/tmp/kras-storm-full-tests.log`: the complete local suite passed 13,884
  assertions after these changes, including Goal Guard, Magnet, replay and
  full-length race regression cases. Device acceptance remains pending.
  The development CI matrix includes this ruleset. Production remains off.

## Sky Court lifecycle and tilted-world replication

Platform banking and engine pulses now advance with the match simulation, not
independent tweens. Pause freezes them and restart/cleanup level the arena
immediately. Slope acceleration updates retained ball speed, so the next ball
tick cannot discard it. Court markings, keeper paddles, engines and ball height
follow the tilted plane instead of clipping through the floor. Authored mesh
transforms are reused without cumulative transformation drift.

The network adapter extends the shared ball presenter with bounded bank, engine
index, warning/tilt/cycle timers and monotonic event sequences. The guest never
advances those timers or applies slope impulses. Invalid state is rejected at
both client and room boundaries; first, repeated, reconnected and next-round
snapshots cannot replay historical tilt feedback. The game now uses keeper
controls, retaining movement, attack and dash without an unused aim stick.

- `/tmp/kras-sky-surface.log`: 41 lifecycle/surface assertions passed, including
  pause, immediate reset, 30/60/120 Hz banking, retained speed and cleanup.
- `/tmp/kras-sky-network-unit.log`: 244 state/replication assertions passed.
- `/tmp/kras-sky-surface-visual.log`: 248 graphical assertions passed.
  `/tmp/kras-sky-surface.png` was inspected after correcting floor/marking
  alignment. A prior capture showed a background-triggered pause overlay; the
  fixture now resumes before capture. This is desktop QA, not device approval.
- All 42 server tests passed, including sky-specific room rejection checks.
- `/tmp/kras-sky-import.log`: import completed. `/tmp/kras-sky-compile.log`:
  all 243 scripts compiled.
- `kras-network-smoke-tY9qAU`: ordinary matches passed with two humans/two bots
  and four humans, including observed warning/banking, reconnect and matching
  results. Guests received 1088-1107 snapshots. The server event-loop maximum
  was 52 ms; this is not a device FPS or Internet-latency certification.
- A subsequent geometric regression (`/tmp/kras-sky-slope-direction-before.log`)
  failed: the visual slope rose in the force direction. The rotation axis was
  corrected and every authored direction is now covered. The initial network
  and graphical results above predate that correction; they are not final
  acceptance evidence for the corrected physics.
- Post-correction tournament `kras-network-smoke-ojwis6` passed three matches
  with two humans/two bots and four humans, including reconnect and agreed
  standings. Points were [6, 7, 9, 13] and [8, 6, 11, 9]; neither required a
  final tie-break. Guests received 1665-1684 snapshots; server loop maximum
  was 38 ms. A late input after room closure was rejected as `not_joined`.
- Portrait inspection then found the upper keeper behind the HUD. Shared
  COURT framing now fits the projected court below the measured HUD and above
  default touch areas, preserving north-up orientation. Regression projections
  cover both orientations and zero through four touch players.
- `/tmp/kras-sky-camera-tests.log`: 202 assertions passed (the unprivileged
  macOS run also logged a system-CA access warning; not an application test
  failure). `/tmp/kras-sky-camera-portrait.log` and
  `/tmp/kras-sky-camera-landscape.log`: 260 graphical assertions passed each.
  Both corresponding PNGs were inspected; all keepers are clear of the HUD.
  These are desktop fixtures, not physical-iPhone touch/performance approval.
- Final local quality gate `kras-party-check.fQzKhW` passed: 243 scripts compiled,
  280 resources/21 autoloads/27 routes/eight characters audited with zero issues,
  14,268 assertions, the real three-lap race regression, and 39 stability matches
  with zero failures. The gate also rejects runtime/leak diagnostics.
  The save suite deliberately logged a failed temporary-file write during
  `failed write stays dirty and can be retried`; that injected failure passed
  its retry/preservation assertions, rather than being an unexplained error.
- Final-source ordinary-network rerun `kras-network-smoke-gVm7OM` passed with
  two humans/two bots and four humans, including host/guest reconnect, warning
  and tilt observation and identical results. Scores were [16, 17, 20, 20]
  and [18, 12, 22, 10]; guests received 1088-1107 snapshots. Server loop
  maximum was 51 ms, not an iPhone rendering-performance measurement.
- Physical-device acceptance remains pending; production deployment is still
  disabled. CI run `36967949347` belongs to the preceding Storm Heart commit
  `94a5222dc333e0343f2582515fda27b9d8c5e12f`, not this Sky Court revision.

## Shared falling-floor lifecycle prerequisite

Before adapting Crumble Court, direct tests exposed shared ArenaTile defects:
forced collapse retained its collision layer and skipped the collapse event;
restore retained the warning mesh offset; warning shake used wall-clock time.
The same tile implementation is used by Color Stand and paint games.

Forced and timed collapse now share one idempotent state transition that
removes collision and emits the event once. Warning motion uses simulation
time, and one owned material is reused instead of filling the shared material
and texture caches with intermediate warning colors. Restore clears the offset.
Color Stand also resets its call stage, progression, timer and painted floor
at round start instead of resuming the previous round's drop phase.

- `/tmp/kras-tiles-before.log`: six failing assertions reproduced the original
  tile defects. `/tmp/kras-color-reset-before.log` additionally reproduced the
  missing Color Stand reset (97 failed assertions, many for individual tiles).
- `/tmp/kras-tiles-integration.log`: 142 assertions passed after correction,
  including real physics-ray collision removal, material identity/cache bounds,
  neutral-material isolation, warning pause, timed/forced fall, respawn and
  all Color Stand floor tiles on restart.
- Complete gate `kras-party-check.zpzb59` passed: 244 scripts compiled,
  281 resources audited with zero issues, 14,409 assertions, the real three-lap
  race regression and 39 stability matches with zero failures. These are
  desktop/headless checks, not physical-device performance certification.
- That prerequisite commit did not enable either game online. Crumble Court's
  subsequent adapter is described below; Color Stand remains offline-only.

## Crumble Court world adapter

The canonical tile ordering is checked against every authored coordinate for
two, three and four players. Both server and client reject missing tiles,
nonfinite/coerced numbers, fractional phases/event counters, out-of-bounds
heights and inconsistent solid/warning rows. Hidden tiles have a canonical
height, rather than transmitting arbitrary overshoot after a long tick.
The initial unit fixture deliberately used a two-second fall tick; its -60 m
hidden height exposed this boundary mismatch, fixed before acceptance.

- `/tmp/kras-crumble-unit-final.log`: 2509 assertions passed before the final
  online-scene fixture change. Node server tests: 44 passed.
- `kras-network-smoke-ouGSBG`: ordinary matches passed for two humans/two bots
  and four humans with real floor warning/fall, reconnect and matching results.
  Scores were [6, 10, 10, 14] and [4, 8, 12, 16]; guests received 667-700
  snapshots. Server loop maximum was 41 ms, not an iPhone FPS claim.
- Initial portrait/landscape desktop fixtures passed 2514 assertions each,
  but visibly included the hover machine. Investigation found the online
  runtime disabled ambient power-ups yet still constructed the machine,
  whose direct delivery bypassed that toggle. Previous claims above that
  machine drops were excluded were therefore too strong for those revisions.
  The shared match builder now omits the machine only in online context;
  offline behavior remains. Every real network peer now rejects a scene with
  a machine, so all adapted games exercise this invariant in subsequent CI.
- The initial ordinary-network and graphical evidence predates that runtime
  correction. The graphical fixture now uses online context with a stub
  transport rather than an offline scene.
- Post-correction tournament `kras-network-smoke-7EDCle` passed three matches
  with two humans/two bots and four humans. Both finished with [3, 6, 9, 15]
  points and no final tie-break. Guests received 1049-1075 snapshots and the
  server loop maximum was 47 ms. This scripted input test is not balance QA.
- `/tmp/kras-crumble-online-portrait-final.log` and
  `/tmp/kras-crumble-online-landscape-final.log`: 2518 assertions passed each.
  Corresponding PNGs were inspected with all four players and mixed floor
  phases visible. A prior online fixture capture had a local pause menu from
  window focus changes; the fixture now closes and checks that menu explicitly.
  These are desktop fixtures, not iPhone/iPad approval or live Internet QA.
- Final-source ordinary rerun `kras-network-smoke-qYFu7I` passed both rosters,
  including the new machine-absence invariant, warning/fall observation,
  reconnect and identical results. Scores were [4, 8, 14, 14] and
  [4, 8, 12, 16]; guests received 681-715 snapshots, server loop maximum 38 ms.
- Full local gate `kras-party-check.ItWpFi` passed: 246 scripts compiled,
  283 resources/21 autoloads/27 routes/eight characters with zero audit issues,
  16,920 assertions, the real three-lap race regression, and 39 stability
  matches with zero failures. The offline machine tests also still pass.
- Production online stays disabled; physical-device, Internet and new-source
  multi-engine checks for the other games remain release gates. The shared
  machine-absence assertion will run for every game in the next CI dispatch.
  Run `36967949347` still targets `94a5222`, before this correction.

## Blast Ball lifecycle prerequisite

Before adding its network adapter, tests exposed that a new round retained the
previous fuse, attacker credit, cooldowns, position and sudden-death fuse limit.
The shared GameBall also emitted an explosion on every subsequent tick when a
listener did not rearm it. Launch now clears a detonation latch and refreshes
the fuse label immediately; detonation emits once and returns before consulting
the previous physics overlap list after a listener has rearmed the ball.
Blast Ball round start now restores the configured fuse and launches anew.

Homing also used a fixed 12 percent blend per tick, making its strength depend
on update frequency. It now uses elapsed-time exponential response calibrated
to preserve the original 60 Hz blend.

- `/tmp/kras-blast-before.log`: nine assertions failed before the lifecycle fix.
- `/tmp/kras-blast-homing-before.log`: both 30/60 and 60/120 Hz comparisons
  failed before correcting steering response.
- `/tmp/kras-blast-lifecycle-final.log`: 15 assertions passed, including a
  rearming signal listener that must not consume old overlap contacts, renewed
  launch identity, cooldown/credit reset and heading agreement within 0.03 rad.
- This prerequisite does not enable Blast Ball online. Its authoritative ball,
  fuse, explosion presentation and multi-engine verification remain required.
- Full local gate `kras-party-check.oc9lX6`: 247 scripts compiled, 284 resources,
  21 autoloads, 27 routes and eight characters audited with zero issues;
  16,934 assertions, the real three-lap race regression and 39 stability
  matches passed with zero failures. This is not physical-device performance
  or App Store distribution evidence.
- GitHub run `36967949347` completed successfully for all 13 jobs on
  `94a5222dc333e0343f2582515fda27b9d8c5e12f`. It predates Sky Court,
  Crumble Court, the machine-creation guard and this lifecycle fix; a new
  source-pinned run is required for those changes.

## Expansion checklist per game

### Color Stand room integration

Both client/server room allowlists include `color_stand` only on `color_floor`.
Snapshots require complete `validColorWorld` data and host ownership. The
multi-engine harness verifies the called color, stage/timer, every tile's
palette tag, height/state and disabled guest collisions, plus an observed drop.
Scripted input seeks the nearest visibly called-color tile; it does not change
the host's rules, timer, palette or results.

- `npm test`: 48 tests passed, including room-level rejection of the wrong
  arena, absent call data and non-host snapshot publication.
- Ordinary run `kras-network-smoke-kvWMwO`: two-human/two-AI and four-human
  cases passed, with guest reconnect and host result-transport loss. Scores
  agreed at [16, 16, 6, 6] and [16, 16, 16, 16]. Guests received 1088-1107
  world snapshots, and the local server loop maximum was 63 ms. Scripted
  safe-tile input is a protocol test, not a balance or human-playability study.
- Tournament run `kras-network-smoke-9wJ5g6` passed six matches per case:
  three regular matches plus all three bounded tie-break attempts. Two-human
  standings [12, 12, 5, 4] ended with shared champions [0, 1]; four-human
  standings [9, 9, 9, 9] ended with shared champions [0, 1, 2, 3]. All clients
  agreed, including reconnects and spectator handling. Guests received
  3279-3298 world snapshots; local server loop maximum was 61 ms.
- Full gate `kras-party-check.REVpk0`: 250 scripts compiled, 287 resources
  audited with zero issues, 17,460 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- Replicated-floor orientation fixtures: `/tmp/kras-color-network-portrait.png`
  (540x960) and `/tmp/kras-color-network-landscape.png` (960x540), 441 assertions
  each. Both were visually inspected: four players, surviving yellow tiles,
  missing unsafe tiles and touch controls remain visible without overlap.
  These are static desktop snapshot fixtures, not recorded online gameplay
  or iPhone/iPad store screenshots.
- Production is not enabled by this room allowlist change; physical-device
  and Internet conditions remain unverified.

### Quick Draw room integration

Client/server development allowlists accept `quick_draw` only on `draw_stage`.
The server requires the validated draw-world payload and host ownership. The
multi-engine fixture reacts only after the visible signal, checks accepted
responses for each local participant and verifies replicated prompt, ordering
and false-start locks. It does not assert movement for this stationary game.

- `npm test`: 50 tests passed, including arena selection, missing state,
  forbidden hidden timing and non-host publication checks.
- Initial ordinary run `kras-network-smoke-e46C0x` failed on the test's array
  equality: decoded JSON slots were floats while the presenter stores ints.
  `/tmp/kras-draw-json.log` reproduced `[2, 0]` versus `[2.0, 0.0]` in isolation.
  Comparison now normalizes already-validated integer slot values, retaining
  order/count checks. No game score or state rule was weakened.
- Ordinary run `kras-network-smoke-qKIudT`: two humans/two bots and four humans
  passed, with results [18, 12, 3, 5] and [18, 8, 7, 8]. Guest reconnect and
  host result-transport loss recovered. Guests received 1087-1107 world
  snapshots; local server loop maximum was 43 ms.
- Tournament run `kras-network-smoke-NCUpwO`: both cases completed three matches
  and agreed on final points [15, 9, 4, 5] and [15, 8, 6, 5], champion slot 0.
  Guests received 1665-1684 world snapshots; loop maximum was 45 ms. Two
  in-flight inputs were rejected as `not_joined` after the four-human room
  closed; clients completed successfully. The subsequent bounded input-drain
  fix is recorded below. This run did not exercise a final tie-break.
- Full gate `kras-party-check.OM0eAT`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,590 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- The scripted immediate-response results show host transport advantage.
  Same-tick tie scoring does not solve Internet latency; this remains a
  development-only ruleset, not production or ranked-play approval.

### Symbol Echo lifecycle prerequisite

Each new match round resets sequence length, progress, pad-entry tracking,
mistakes, finish order, illumination and display cursor, then deals a fresh
sequence with a new serial for AI memory invalidation. Pad illumination now
advances only with controller simulation time, not an independent scene tween.
Same-tick sequence finishers share the placement bonus; completed sequences
cannot award it again on another input scan.

- `/tmp/kras-echo-before.log`: 22 assertions failed on stale round state and
  flash expiration while controller simulation was stopped.
- `/tmp/kras-echo-ties-before.log`: three failures reproduced slot-based bonus
  differences when all four participants finished in the same tick.
- `/tmp/kras-echo-final.log`: 36 assertions passed after both repairs.
- Full gate `kras-party-check.UJkgBy`: 254 scripts compiled, 291 resources
  audited with zero issues, 17,625 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- Symbol Echo is still offline-only. Its future adapter must reveal only the
  currently shown symbol, not the secret sequence. At this lifecycle commit
  AI still queried the expected pad with recall errors. The subsequent observed
  memory repair is recorded below.

### Symbol Echo observed AI memory

The controller exposes only the currently illuminated symbol and its displayed
step, alongside visible phase/length and the player's own progress. Echo AI
samples this cue once, stores a difficulty-dependent remembered value and waits
its reaction delay before using it. It no longer calls `expected_pad` or receives
the true answer during input. Missed observations produce seeded guesses that
exclude disproven choices; repeated queries cannot reroll the same belief.

Miss feedback now invalidates the attempted step rather than progress zero after
a reset. Repeated-symbol movement leaves the pad fully before returning, avoiding
oscillation at its boundary. A real four-AI fixture observes [0, 0, 1] and checks
that a competitor can complete that repeated-symbol sequence.

- Initial perception unit run: 21 assertions passed.
- `/tmp/kras-echo-perception-movement.log`: real movement exposed non-normalized
  slerp-axis errors and failed repeated-symbol completion.
- `/tmp/kras-echo-movement-diagnostic.log`: planar yaw removed rotation errors;
  progress still stalled at [1, 1, 1, 2], identifying boundary oscillation.
- `/tmp/kras-echo-perception-final.log`: 38 assertions passed after explicit
  pad-exit state. The suite also includes direct near-opposite walking-turn
  checks in the subsequent full gate.
- Walking facing now interpolates planar yaw and reconstructs a normalized
  horizontal vector. This addresses the observed nearly opposite-direction
  failure without changing vehicle steering or movement acceleration.
- Full gate `kras-party-check.OojJ2s`: 255 scripts compiled, 292 resources
  audited with zero issues, 17,674 assertions passed, race regression passed
  and 39 stability matches completed with zero failures. No normalization,
  script or parse errors were found in this gate's logs.
- This is one AI category's perception repair, not a claim that every other
  brain has been audited or that Symbol Echo is online-ready.

### Closed-room input drain

Closing a played room now records a one-second, connection-local retired epoch.
Well-formed inputs for that closed epoch (or an earlier epoch in that room) are
discarded, never forwarded. Unknown connections, malformed inputs, future
epochs, snapshots and results remain rejected. Join/resume clear this marker;
closing a lobby that never played does not create an allowance. The existing
transport rate limits still apply, and session tokens are still removed.

- A regression test first reproduced `not_joined` for an in-flight input.
- `npm test`: 52 tests passed after the fix. Tests cover timeout, outsiders,
  malformed inputs, forbidden authority, no forwarding and another room.
- The real WebSocket integration test now closes a four-client match after
  reconnect, sends an old input followed by a ping barrier, and verifies no
  error message, room or session remains. Godot gameplay code is unchanged by
  this server-only repair; no new full Godot run is claimed for it.

### Quick Draw adapter verification

`draw_replica.gd` publishes the host's prompt phase, prompt number, accepted
response order, false-start locks and monotonic feedback counters. It excludes
the hidden random wait duration and signal age. Both Godot and Node validators
reject missing fields, unexpected timing fields, duplicate/out-of-range slots,
locked participants in the response order and responses during WAIT.

Guests present the pillar state and host decisions without advancing timers or
awarding points. Fresh events play once; initial snapshots, repeated rendering
and reconnect gaps suppress historical sounds.

- `/tmp/kras-draw-network.log`: 83 assertions passed, including JSON round trip,
  malformed state rejection, presentation, score/timer non-authority and event
  freshness. `npm test`: 49 server tests passed.
- Full gate `kras-party-check.DFgBMB`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,552 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- At the adapter-only commit room allowlists excluded Quick Draw; subsequent
  room work is recorded above. Actual mobile presentation and latency fairness
  remain pending. Response order is an ordered list of participants,
  not a unique placement: same-tick participants can share a scoring rank.

### Quick Draw simultaneous-response fairness

Responses sampled during the same simulation tick now share the same rank and
points. Later responses rank after all preceding participants (two first-place
responses earn three points each; the next response earns one point). This
removes the previous advantage assigned to lower-numbered player slots.

- `/tmp/kras-draw-ties-before.log`: 12 failures reproduced slot-order bias over
  all ordered pairs of distinct players.
- `/tmp/kras-draw-ties-after.log`: 47 assertions passed, including all pairs,
  later responses, match reset and spectator exclusion.
- Full gate `kras-party-check.tfBnE4`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,588 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- This fixes local same-tick fairness only. It does not compensate network
  transport delay or establish fairness across Internet connections.

### Quick Draw round reset

Each new match round now clears the prior signal age, response order and
false-start locks, resets the prompt counter and starts a fresh random wait.
Inactive players cannot register responses or false starts. This prevents
spectators from affecting reaction ranking and penalties.

- `/tmp/kras-quick-before.log`: eight failing assertions reproduced stale
  round state and spectator penalties before the fix.
- `/tmp/kras-quick-after.log`: 11 assertions passed after the fix.
- Full gate `kras-party-check.gxPb9f`: 251 scripts compiled, 288 resources
  audited with zero issues, 17,470 assertions passed, three-lap race regression
  passed and 39 stability matches completed with zero failures.
- At this lifecycle-repair commit Quick Draw remained excluded from online
  rooms. Subsequent adapter and room evidence is recorded above; the lifecycle
  repair alone was not evidence of network readiness.

### Color Stand snapshot adapter

`color_replica.gd` captures the authored 121-tile quilt, palette index per tile,
called color, phase and timer. It reuses the falling-floor codec/presenter with
an explicit internal tile-count parameter; Crumble Court still validates its
original 113-tile layout by default. Guests present tile heights/visibility and
palette without advancing floor physics, countdowns or scoring.

Monotonic call/drop sequences gate countdown/whistle feedback. First snapshots,
repeated snapshots and reconnect gaps cannot replay old cues. The shared match
dispatcher validates Color Stand state before applying it. The server has a
matching `validColorWorld` validator. Room integration is recorded above;
at the adapter-only commit this was not wired into room acceptance.

- `/tmp/kras-color-replica.log`: 430 assertions passed for JSON round-trip,
  missing/malformed fields, palette bounds, complete floor, host target,
  disabled guest collision, stopped countdown and feedback freshness.
- `npm test`: 47 tests passed, including new color bounds and existing
  Crumble Court validation/room regressions.
- Full gate `kras-party-check.88gtJ5`: 250 scripts compiled, 287 resources
  audited with zero issues, 17,460 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- At the adapter-only commit Color Stand was excluded from room allowlists. Remaining work then:
  room integration, multi-engine ordinary/tournament tests, reconnect state
  agreement and presentation captures from the replicated floor.

### Color Stand readability prerequisite

Reviewing the next candidate found that the HUD displayed only the game title
and timer, never the chosen color. The AI could read `called_tag`, but humans
could not learn that choice from the prompt. The HUD also kept the previous
nonempty banner when a controller intentionally returned an empty string.

The call now uses localized color names (all four in Arabic/English) and the
remaining timer. Shared HUD refresh accepts an empty banner, clearing the
expired hurry instruction during floor restoration.

- `/tmp/kras-color-call-before.log`: 17 assertions failed, covering missing
  color names in both languages and the stale restoration banner.
- `/tmp/kras-color-call-after.log`: 160 assertions passed after correction.
- Full gate `kras-party-check.8kVdKP`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,031 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- `/tmp/kras-color-portrait.png` (540x960) and
  `/tmp/kras-color-landscape.png` (960x540) were inspected. Both show the
  called yellow color, time, four players, complete floor and touch movement.
  Their corresponding logs each passed 161 assertions. These are static
  desktop QA fixtures, not evidence of an online match or device performance.
- Color Stand remains excluded from online rooms until its tile palette,
  collapse states, called color and phase timers are authoritatively replicated
  and tested across connected engines. Naming colors does not yet provide
  non-color tile symbols for color-vision accessibility.

### Blast Ball room integration

Both room and client allowlists now permit only `ember_pit` for Blast Ball.
Room snapshots require `validBlastWorld` and retain host-only publication.
The engine harness and CI matrix include this ruleset, with assertions that a
decreasing fuse and an actual explosion occurred, and that guest fuse,
detonation, launch identity and collision mask agree with the final host state.

- `npm test`: 46 tests passed, including room-level missing-fuse rejection,
  incorrect-arena rejection, non-host snapshot denial and valid relay.
- Initial ordinary run `kras-network-smoke-oxaGdn` failed the explosion
  observation gate: fixed diagonal scripted inputs exited the arena too early.
  No gameplay fuse was shortened to make the test pass. Scripted humans now
  steer around an inner ring, allowing the actual five-second fuse to expire.
- Ordinary run `kras-network-smoke-YlbFzX` passed both two-human/two-AI and
  four-human cases, including guest reconnect and host result-transport loss.
  Final scores agreed: [16, 8, 11, 6] and [4, 12, 16, 16]. Guests received
  852 and 1065-1084 world snapshots; local server loop maximum was 64 ms.
  These scripted-input results are not a balance evaluation or mobile FPS test.
- Tournament run `kras-network-smoke-Uvid91` passed three matches for both
  two-human/two-AI and four-human cases, with matching final accounting and
  reconnections. Points were [13, 7, 6, 7] (champion slot 0) and [10, 7, 11, 7]
  (champion slot 2). Guests received 1353 and 1642-1661 world snapshots. Neither
  final standing required sudden death in these runs. A local server event-loop
  spike reached 143 ms; successful correctness checks do not certify latency.
- Final gate `kras-party-check.LJvbhj`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,013 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- Physical-device QA remains pending for this integration. Production
  endpoint/configuration is unchanged. Desktop orientation evidence follows.

### Blast Ball orientation polish

The optional `--capture-blast=<path>` fixture renders a validated host snapshot
with all four players and one real touch-control layout. It is a static QA
fixture, not recorded online gameplay or an App Store marketing screenshot.

Initial portrait/landscape inspection found the above-ball fuse too small and
the description incorrectly suggesting a held-item mechanic. The explosive
Label3D now uses a larger pixel scale and higher anchor. Arabic and English
describe hitting the ball away and elimination within the blast radius.
The fixture also resets its round index before capture rather than inheriting
the preceding synthetic round-transition test.

- `/tmp/kras-blast-portrait-final.png` (540x960) and
  `/tmp/kras-blast-landscape-final.png` (960x540) were opened and inspected.
  Four players, the ball/fuse, HUD and touch actions are visible without overlap.
- Corresponding `*-final.log` files: 100 assertions passed in each graphical
  run, with no reported leaked rendering resources.
- `/tmp/kras-blast-polish-content.log`: 121 assertions passed, including
  localization key parity and content references.
- `/tmp/kras-blast-polish-goal.log`: 120 Goal Guard assertions passed after
  the shared GameBall label change; normal-ball rules remain unchanged.
- This targeted presentation change does not replace physical-device QA,
  safe-area checks on iPhone/iPad, or frame-time/battery measurements.

### Blast Ball adapter in development

`src/net/blast_replica.gd` now captures and presents host-owned position,
velocity, launch generation, fuse, terminal detonation and a monotonic
explosion sequence/location. The shared match snapshot dispatcher validates
this world before acceptance. Presentation does not tick physics or fuse and
cannot eliminate players or award points. Launch identity forces a snap;
ordinary movement interpolates. Exploded balls hide until the next launch.

Explosion feedback is separated from authoritative damage. First snapshots,
round changes and reconnect gaps suppress old feedback; repeated snapshots
cannot replay an already consumed event. `validBlastWorld` supplies the same
numeric/type bounds on the server. At the adapter-only commit it was not yet
wired into room acceptance; the integration status above supersedes that limit.

- `/tmp/kras-blast-replica-tests.log`: 94 assertions passed, including shared
  snapshot dispatch, malformed data rejection, unchanged scores/alive state,
  stopped fuse, teleport, visibility and feedback replay suppression.
- `npm test`: 45 tests passed after allowing the local WebSocket listener.
  The initial sandbox run failed only at `listen EPERM 127.0.0.1`; it was not
  counted as a passing transport test.
- Full gate `kras-party-check.Q4Nmkc`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,013 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- At the adapter-only commit Blast Ball was excluded from room allowlists. Remaining acceptance then was:
  room-level validation, ordinary and tournament multi-engine tests with
  actual fuse/launch/explosion observations, and portrait/landscape captures.
  This work is not production activation or App Store readiness.

1. Define a bounded world-state adapter for all gameplay-visible dynamic objects
   (balls, projectiles, crates, hazards, ownership, effects), not just players.
2. Keep the host as the sole rules/score authority. Never simulate a second
   independent match on guests and call that synchronization.
3. Add malformed snapshot, reconnect, round reset and result tests.
4. Run real multiple-engine tests and device visual/audio QA.
5. Add the game to both server and client allowlists only after those pass.
6. Verify score direction and tournament placement for the new game, including
   contender-only tie-breaks, reconnect and host loss.

WebSocket is used here because the existing HTTP deployment can relay it;
its TCP latency tradeoff still requires real-network testing. References:
[Godot WebSocket guide](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html),
[ws](https://github.com/websockets/ws).

## Structure

```text
server/
  rooms.js             # protocol/state/ownership, independent of transport
  tournament.js        # points/cups, seeded rotation, bounded tie-breaks
  tournament.test.js   # accounting, ties, rotation and immutable views
  multiplayer.js       # bounded WebSocket transport, heartbeat, shutdown
  rooms.test.js        # state and actual four-socket integration tests
  network-smoke.js     # real multi-process Godot integration
src/net/
  net_service.gd       # local + online session coordinator
  room_client.gd       # Godot WebSocket transport
  match_replica.gd     # shared player/phase state and world adapter dispatch
  goal_guard_replica.gd # bounded ball/charge presentation, no guest simulation
  collectible_replica.gd # shared gem/star visual reconciliation without physics
tests/
  network_peer.gd      # actual match client used by the smoke test
  suites/test_network.gd
```
