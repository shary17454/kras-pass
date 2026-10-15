# Armed Race Character Impact Response

Feature branch: `fix/kras-race-impact-character-response`, parent
`69555a5007c8e2bc12d5f28a6f227829ec1ee212`. Not main, production or an
App Store submission.

## Proved Defect

Rocket Rally's bomb/missile `_spin_out` applied identical fixed impulses and
stun to every character. It bypassed effective resistance (including Sakhra's
passive) and Nabta's recovery passive, unlike ordinary Fighter hit response.
The real-scene regression failed six assertions, with 52 passing, before the
runtime edit. This is a stat-application defect, not by itself proof of the
cause of the campaign's character win imbalance.

The correction scales the weapon impulse by neutral effective resistance
divided by the victim's effective resistance, and multiplies the fixed spin
duration by the victim's recovery perk. Neutral impulse and duration remain
unchanged. Existing shield interception, finished/recovering exclusions, no
health damage, hit credit and weapon presentation events remain intact.
No character definition, speed/acceleration, AI advantage, scoring, race
duration, checkpoint or balance-warning threshold was changed.

## Focused Verification

The initial green test passed 58 assertions. The expanded fixture passes 82,
including all eight characters' resistance/perks and response bounds, explicit
heavy/light ordering, neutral response, unchanged health, hit accounting,
shield interception, finished-player protection and round reset.
Armed-race network presentation passes 176 assertions, including real host
world capture and non-authoritative guest weapon behavior. Both strict test
log guards and `git diff --check` pass.

Logs: `/tmp/kras-race-impact-{red,green,expanded-green,armed-network}.stdout`.
Tests use actual local Godot 4.7.1, macOS and isolated save directories.

## Full Current-Source Checks

`tools/check_party.sh` completed with exit zero:

- All 394 scripts compile.
- 439 resources, 22 autoloads, 27 routes, eight characters, zero inventory issues.
- 366440 assertions pass in 403.8 seconds.
- Race regression and six boss probes pass.
- 39 stability matches complete with zero failures.
- Every stage log guard passes.

Main stdout: `/tmp/kras-race-impact-full-gate.stdout`.
Detailed evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.nTlW8x`.

The six actual current Godot world captures from this run were supplied to
server `npm test`: all 193 passed, zero failed and zero skipped. The real
localhost socket test ran in the local macOS session, not an environment that
blocks listener creation. Log: `/tmp/kras-race-impact-server-fixtures.stdout`.
These results do not establish physical-device FPS, thermals or battery life.

## Comparison Baseline

The preceding completed 24-baseline/16-difficulty/two-mutator cohort is retained
as the before sample, rather than relabeling an old-source report as current:
`/tmp/kras-drive-handling-expanded-after-report/report.json`.
Runtime source was `720df44b02c03c29725f554d78d00775f878502f`, with fingerprint
`855cd9856bc9b174f0fd3b0327e5098fe384a17c4fa0445c98b0fe0c0403fbf2`.
The parent `69555a5` differs from that commit only in documentation; this was
verified with Git. The before report retains `character advantage`, character
bias 0.291666666666667, Expert rank share 0.7 (not win rate), and wins
Barq 10/Nabta 6/Ghaim 5/Ramla 2/Fanoos 1. Do not claim the defect correction
has resolved that balance finding without the new comparison results.

## Natural After Comparison

The new source completed 24 natural baseline races, 16 mirrored same-character
difficulty races and two mutator/chaos races, with exit zero in 572.7 seconds.
The paired comparison therefore uses 84 completed matches, including the
retained preceding 42-match before cohort. No race window or warning threshold
was changed. Identical baseline seeds and difficulty seed/character/slot
pairings were verified. Every paired racer finished three laps. Source
fingerprints were stable and the strict runtime guard passed.

After fingerprint:
`539552917cc9f5635ea3588cf5d5aec20db677c41bc2a1ae99f18e1cc0f2b379`.
After report: `/tmp/kras-race-impact-natural-after-report/report.json`.

| Metric | Before | After |
| --- | ---: | ---: |
| Baseline mean duration (seconds) | 129.984027777774 | 131.241666666664 |
| Expert rank share | 0.7 | 0.7 |
| Character bias | 0.291666666666667 | 0.25 |
| Slot bias | 0.125 | 0.0833333333333333 |
| Barq wins | 10 | 9 |
| Nabta wins | 6 | 6 |
| Ghaim wins | 5 | 4 |
| Ramla wins | 2 | 4 |
| Fanoos wins | 1 | 1 |

Slot counts changed from `[8,9,4,3]` to `[7,8,5,4]`. Both reports retain
`character advantage`. Observed bias decreased in this cohort, but this is
not independent-seed population confidence, a solved balance issue, or a
READY promotion. The retained change fixes proved stat/perk application;
wider race balance remains open.

## Open Release Gates

Representative independent-seed balance and remaining fair-AI review,
current-source real-network qualification, physical-device human/gamepad/
orientation/performance/thermal/battery QA, qualified integration, coordinated
Railway protocol rollout, new release numbering, and exact-source signed
local Xcode 27 Archive/upload/processing/review remain required.
The previous unsigned iOS build predates this correction.
