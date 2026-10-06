# Vehicle Character Handling Qualification

Feature branch: `fix/kras-drive-character-handling`, based on
`4573085c41442c6e1ca4ae0c03a6a8c2bd76812d`. Not main or a released build.

## Defect and Scope

The shared DRIVE integrator used the global `drive_steer` without applying
the character's effective `turn_rate`. Speed and acceleration differences
worked, but handling differences and Ramla's turn passive did not. The fix
normalizes effective turn rate against the neutral character's tuning value,
preserving existing neutral steering. Character stats, checkpoints, AI,
items, balance thresholds and race completion rules are unchanged.

The focused test failed seven handling assertions before the runtime edit
(90 passed, seven failed). After the edit all 97 assertions passed, covering
walking/combat budgets, vehicle speed/acceleration/steering budgets, all eight
characters including turn perks, and neutral handling parity.

Logs: `/tmp/kras-drive-handling-{red,green}.log`. The initial sandbox invocation
crashed while accessing user logs; it is not the red reproduction. The
qualified red/green tests ran with the actual local Godot 4.7.1 and isolated
save directories.

## Initial Natural Comparison

Both runs used seed offset 1500000, natural round window 140 seconds, two
baseline races, 16 mirrored same-character difficulty races and two
mutator/chaos races: 40 completed matches in total. All 16 paired races per
source completed and every paired racer finished three laps. Strict runtime
log guards passed. Seed/roster pairings and immutable source fingerprints
were verified. Fanoos' two paired result records are exactly identical before
and after, providing an additional neutral parity check.

| Metric | Before | After |
| --- | ---: | ---: |
| Baseline mean duration (seconds) | 129.58333333333 | 131.066666666664 |
| Expert rank share (not win rate) | 0.7 | 0.7 |
| Baseline slot bias | 0.25 | 0.25 |
| Baseline character bias | 0.3 | 0.3 |

Two baseline samples are not sufficient to qualify population character
balance. Empty flags in this tiny sample do not prove removal of the old
24-sample campaign's character advantage. Retain that finding as open; run
wider and independent cohorts before any READY promotion.

The clean baseline checkout was `45340110464e762be05f8d362474bdbbfd86f44c`;
its shared Fighter, kart/rocket controllers, race brains, character definitions
and tuning were verified identical to the parent before the edit.
Before fingerprint: `2d3e970ae4f962679d4025f9ed32ce0fa693b870492f16e9e0b4c61aa51a4072`.
After fingerprint: `855cd9856bc9b174f0fd3b0327e5098fe384a17c4fa0445c98b0fe0c0403fbf2`.
Reports: `/tmp/kras-drive-handling-natural-{before,after}-report/report.json`.

## Expanded Matched Comparison

The follow-up used 24 baseline, 16 mirrored difficulty and two mutator/chaos
matches per source: 84 completed matches. Both processes exited zero and
passed strict runtime log guards, start/end fingerprint equality, identical
24 baseline seeds and mirrored seed/character/slot pairing. All paired racers
finished three laps. Fingerprints match the initial comparison above.

| Metric | Before | After |
| --- | ---: | ---: |
| Baseline mean duration (seconds) | 128.927777777774 | 129.984027777774 |
| Expert rank share | 0.7 | 0.7 |
| Slot bias | 0.0416666666666667 | 0.125 |
| Character bias | 0.291666666666667 | 0.291666666666667 |
| Barq wins | 10 | 10 |
| Nabta wins | 9 | 6 |
| Ghaim wins | 2 | 5 |
| Ramla wins | 3 | 2 |
| Fanoos wins | 0 | 1 |

Both reports retain `character advantage`. Slot counts changed from
`[7,6,6,5]` to `[8,9,4,3]`; do not present the change as uniformly improved
balance. The handling fix is a proved stat-application correction, not a
resolved character-balance finding or READY promotion. This remains a limited
cohort, not an independent-seed population estimate.

Reports: `/tmp/kras-drive-handling-expanded-{before,after}-report/report.json`.
The next concrete candidate to investigate is the armed-race `_spin_out` path:
it calls `stun(SPIN_SECONDS)` and `apply_impulse(... * 7.0 + UP * 2.0)` directly,
unlike `Fighter.take_hit`, which applies resistance and recovery modifiers.
This source observation is not yet a tested correction or proof that it
explains the remaining win imbalance.

## Full Current-Source Gate

`tools/check_party.sh` completed with exit zero:

- All 394 scripts compile.
- Inventory: 439 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- 366393 assertions pass in 392.8 seconds.
- The race regression and six boss probes pass.
- All 39 stability matches pass with zero failures.
- All stage log guards and `git diff --check` pass.

Main log: `/tmp/kras-drive-handling-full-gate.stdout`.
Detailed evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.1aIbTH`.
These are macOS headless checks, not physical iPhone FPS or battery evidence.

## Actual Local Network and Server Qualification

At source `720df44b02c03c29725f554d78d00775f878502f`, separate Godot
processes and the real local WebSocket service passed Rocket Rally at seed
1504242, both with two automated human-input peers plus two bots and with
four automated human-input peers. Host and the designated guest reconnected;
the other two peers in the four-peer case were not reconnect subjects.
Movement, armed pickups/weapons and final score/world agreement were checked
by the real network runner. A separate JSON check verified identical scores
across all peers and exactly two reconnect subjects in each case.

- Two peers: `[17219,17730,1999973520,1999971924]`, 3852 replica worlds.
- Four peers: `[17537,18087,18079,18025]`, replica world counts 3999/3999/3979.
- Log: `/tmp/kras-drive-handling-network.stdout`, exit zero.

In the two-peer case, the bots were progress-ranked when the human competitors
finished, as specified by the existing race completion rule; the large bot
scores are not finish times. This case does not prove all four racers finished.
The four-peer case requires all four human competitors to finish their laps.
Server loop maximum 248 ms was observed under concurrent simulations. This
is not acceptable evidence for physical FPS, battery or Internet latency.

All six current Godot world captures from the full gate were supplied to server
tests. The first sandbox run passed 192 and failed the real WebSocket test with
`listen EPERM`; the actual local macOS rerun passed all 193, zero failed and
zero skipped. Neither a skipped socket test nor the sandbox failure was hidden.
Logs: `/tmp/kras-drive-handling-server-fixtures{,-local}.stdout`.

## Fresh Production Audit (Not a Deployment)

On 2026-10-06, Railway's explicit project/environment/service deployment list
confirmed repository `shary17454/kras-pass`, branch `main`, commit
`062a40992b92958573e28e19d8c8c1840560797a`, successful deployment
`8d235c0c-eac1-4ade-9065-4e3264d36021` created at 01:59:33.330 UTC, with a
`/data` volume. The temporary checkout has no CLI project link; explicit IDs
were used rather than silently linking or deploying an arbitrary project.

Health returned `ok=true`, `authentication_ready=true`, multiplayer disabled.
The unauthenticated account endpoint returned HTTP 401 `sign_in_again`.
Required Apple/owner/database variables were present. Internal boolean checks
confirmed bundle/team/owner alignment and a persistent `/data/` database path;
raw secrets were neither printed nor saved. `MULTIPLAYER_ORIGINS` is absent.
The first origin-presence query used the wrong key and was superseded by a
query using the actual `server/index.js` key; both are diagnostic history, not
evidence of a runtime failure.

Bounded deployment and build log samples contained respectively six and
42 records, with zero error/fatal/failed/uncaught matches. These limited samples
do not establish an error-free service for all time. A read-only SSH SQLite
check returned `quick_check=ok`, zero foreign-key errors and `user_version=0`.
No account rows were read, database exported, or migration/reset performed.
Account/authentication source has no diff against this deployed main commit.

Main's room protocol is 1; the current branch uses protocol 2 and expands
Colossus exposure and crumble warning validation. Therefore production is not
qualified for this client's multiplayer merely because health and local tests
pass. Coordinate integration, server-first rollout and current-client acceptance
before enabling public rooms. No Railway deployment or variable changes were
made in this audit.

Infrastructure tests initially could not import the missing local `railway`
package. `npm ci --ignore-scripts --no-audit --no-fund` installed the locked
seven packages without changing dependency declarations or lockfile. The
subsequent `npm run test:infra` passed all 22 assertions, including destructive
change rejection and secret/volume preservation. This is configuration-test
evidence, not proof that an infrastructure plan was applied.

Fresh Xcode 27 devicectl inspection still reports physical iPhone
`00008140-000E7D291E98801C` unavailable. Simulators do not prove physical
thermals, battery or four real humans on touch/gamepads.

## Release Gates

Current-source network qualification, wider character balance, remaining AI
findings, real-device human touch/gamepad/orientation/performance/battery QA,
coordinated Railway protocol rollout, qualified integration and new release
numbers remain required. This change is not in the previously attested
unsigned iOS build. Rebuild from the final documented commit using local
Xcode 27 before Archive/signing/upload/processing/review.

Live read-only checks confirmed Xcode 27.0 (27A266a) and the installed
`Apple Distribution: Shary ALADHYANI (4HM66AD594)` identity. No P12 import,
certificate changes, Archive, signing or upload was performed in this step.
