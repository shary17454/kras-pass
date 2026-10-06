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
