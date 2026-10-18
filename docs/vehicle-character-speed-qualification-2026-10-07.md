# Vehicle Character Speed: Review Candidate

## Source and Change

Runtime commit: `200324543fcd18ad10e5b3a3161c6aff9d09bf82`.
Parent: `155fabe41431d2846fb798b70ce7e1cf5fc68054`.
Branch: `fix/kras-vehicle-character-speed-budget`.

`fighter.drive_speed_stat_scale=0.35` narrows DRIVE cruising-speed differences
around the unchanged neutral character speed of 14.105. Character speed still
has a nonzero effect; this does not normalize all characters into one identity.
WALK/FLOAT speed, acceleration, steering, weight, combat and character perks are
unchanged. Every input source uses the same formula; there is no hidden AI buff.
The runtime default for configurations without this key remains 1.0.

The shared DRIVE code affects Kart Sprint/Rocket Rally, Scrap Karts and the
turret/tank family. Regression coverage is broader than natural balance coverage;
this candidate is not yet accepted for release.

## Retained Before Evidence

At parent 155fabe, the visible-target repair did NOT remove Rocket Rally's
character-advantage warning. Its 42-match natural run with offset 1200000 has
character bias 0.25, Expert placement share 0.7, zero ties and wins concentrated
in Barq (9), Nabta (8), Ramla (4), Ghaim (2), Mowja (1).

Raw report: `visible-target-rocket-natural-1200000.json`.
SHA-256: `cc34c863f3a90730542a23070f0754268b01fbadb3f20a6948434b9c2c070158`.
Its source fingerprint is
`096a5e758d0301d1d324340147e285d9e3133c887482ebcdd1bd820f0d322a01`.
This failure is retained, not relabeled as a success of the target repair.

The new effective-speed assertions failed before the speed-budget change:
103 passed, 10 failed, exit 1 (`/tmp/kras-vehicle-speed-before.stdout`).
Afterward the focused suite passed 113 assertions, exit 0.
The original 15-percent character checks and neutral handling checks remain.

## Two Natural Rocket Rally Samples

Each sample completed 24 baseline rounds, 16 mirrored difficulty matches and
two short mutator/chaos smoke checks. Baseline rounds finish by actual laps,
not by the report's `round_window` field. The smoke checks are not balance proof.
No balance threshold, seed selection policy or AI input authority was weakened.

| Seed offset | Character bias | Slot bias | Expert share | Ties | Mean simulation duration | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 1200000 | 0.0833333 | 0.0833333 | 0.7 | 0 | 130.3257 s | none |
| 1500000 | 0.125 | 0.125 | 0.7 | 0 | 128.6444 s | none |

All eight characters won baseline rounds in the first sample. Ramla and Turs
did not win in the second 24-round sample; absence of warnings is not proof of
equal population win rates or universal balance. These are two samples, not
thousands of current-source matches across every game and map.

Raw reports:
- `vehicle-speed-rocket-natural-1200000.json`, SHA-256
  `15d2cb80bb3c93bfe5808c1690448061da9cbd482775dac2ada767bdbeb04dfc`.
- `vehicle-speed-rocket-natural-1500000.json`, SHA-256
  `e3b3ba649e8220505921b976ae5a90451ad766920135b7382e7a130d159ac461`.

Both runs exited 0 and passed `check_godot_log.sh`. The existing
`summarizeBalance` validator verified counts, seeded baseline/smoke events,
all eight mirrored character pairs, completion and empty warning lists.
Their start/end source fingerprints equal
`9e589f977babb4ef14a773bfd0c172cab21ab63252453c59e2d5180a84eedb5c`.
An independent Node SHA-256 walk of 272 relevant source files matched it.
The validator still reports `balanceReviewComplete=false` and
`releaseReady=false`; one-game validation cannot certify all 39 games.

## Full Regression on Runtime 2003245

Command: `GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`.
Engine: Godot 4.7.1 official. Evidence: `/tmp/kras-party-check.EPSH0w`.
Completed exit 0, all strict log guards passed:

- 415 scripts compile.
- Inventory: 514 resources, 22 autoloads, 27 routes, 8 characters, zero issues.
- 388629 assertions pass in 419.9 seconds.
- Independent Party Race actual three-lap regression passes.
- Colossus seeds 345, 9614 and 172; Forge, Dreadnought and Sovereign seed 9614
  all pass their explicit defeated-boss checks.
- One stability cycle: 39 matches, zero failures. Settled texture/material/mesh
  and PCM caches are zero; process memory is 140242102 bytes. One cycle is not
  a long memory-leak soak or iPhone energy/thermal measurement.

Retained expected diagnostics: macOS CA lookup `ret != noErr`, intentional
failed-save/failed-route recovery fixtures, deliberate empty-suite rejection
fixtures and the simulated memory-warning test. No new unqualified runtime
error was allowed by weakening the log guard.

Fresh server tests use all six actual engine captures from
`EPSH0w/saves-tests/{armed,siege,forge,dreadnought,sovereign,colossus}-world.json`.
Node 24.18.0: 204 pass, zero fail, zero skipped, 1447.2 ms.
Log: `/tmp/kras-vehicle-speed-server-tests.log`. Local loopback tests do not
qualify production Railway, real Apple authentication or Internet reconnect.

## Remaining Release Gates

Natural current-source balance across the other affected DRIVE games and all
39 games, native 1-4-human input/gamepads/orientation QA, measured physical-device
performance/energy, approved production integration/backup/restore and coordinated
Railway rollout remain required. Resolve the arm64 simulator-template limitation
without falsifying framework metadata; see the companion simulator audit.

No merge to main, Railway rollout, physical-device installation, new archive,
upload, processing or App Review submission occurred for this candidate.
Existing candidate 111 predates this runtime change and cannot be reused as
its release artifact. Use a new frozen source and local Xcode 27 archive after
the remaining gates; do not use Xcode Cloud or import/recreate certificates.
