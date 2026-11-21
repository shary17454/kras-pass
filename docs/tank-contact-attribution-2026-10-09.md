# Tank collision attribution and rejected scale experiment

Runtime source: `5733c7ed91eecd638a1df5863adb1ff008c7baf2`.
Branch: `feature/kras-online-random-rotation`.
Only diagnostics and inherited keeper regression coverage changed here.
No production collision geometry, physics settings or weapon rules changed.

## Rendered trace

Godot 4.7.1, local macOS Apple M5, Mobile renderer, 1280x720, quality 2,
60 FPS cap, tank_foundry, four scripted touch drivers with ordinary firing.
60 steady seconds after three warmup seconds; complete_duration=true; exit 0.
No other local test process ran concurrently with this rendered trace.

- Mean 59.9948 FPS, p95 17.887 ms, p99 19.364 ms, worst 39.724 ms.
- Three frames >25 ms, two >33 ms, none >50 ms; seven live weapons peak.
- 15116 fighter.physics calls: 12.192471 seconds inclusive wall duration,
  maximum 9939 us. The slowest retained contacts involved RockCover3.
- match.rules maximum 2495 us; match.live_tick maximum 12974 us.
- 711 fighter physics intervals met the 4000 us diagnostic threshold.
- No live pipeline compilations; nodes returned from 51 to 51.
- Strict runtime log guard passed.

These nested wall intervals are not exclusive CPU or GPU timings and cannot
be added together. The earlier non-traced 125 ms stall was not reproduced.
Do not claim it is fixed or caused solely by collision or projectile code.

Evidence: `/tmp/kras-tank-firing-trace.{stdout,json,png}`.

## Fixed-contact scale experiment

`tests/cover_scale_probe.tscn` builds the actual tank_foundry rock collider
and the actual fighter. It compares its existing scaled convex shape against
the same vertices with scale applied to the points. It verifies world-space
geometry equality and requires 120 actual rock contacts per phase.
ABBA order limits, but does not eliminate, thermal and scheduler drift.
This is a repeated fixed-pose body-motion probe, not gameplay FPS evidence.

The final isolated run retained geometry equality and all 480 contacts:

| Phase | Mean us | p95 us | Maximum us |
| --- | ---: | ---: | ---: |
| Scaled A1 | 2854.692 | 3631 | 7433 |
| Baked B1 | 2580.725 | 2773 | 2835 |
| Baked B2 | 2903.575 | 3353 | 3585 |
| Scaled A2 | 2652.758 | 2827 | 2992 |

Overlapping distributions do not establish a stable improvement. Therefore
the runtime optimization was rejected; no cover collider was changed.
The initial isolated and intermediate concurrent-test runs remain negative
evidence, not successful optimizations. Final isolated log:
`/tmp/kras-cover-scale-probe-serial.stdout`; exit 0 and strict guard passed.
Earlier logs: `/tmp/kras-cover-scale-probe.stdout` and
`/tmp/kras-cover-scale-probe-final.stdout`.

## Shared scoring regression coverage

The previous keeper-terminal fix is inherited by magnet_court and sky_court
as well as storm_heart. The final-pair regression now covers all four games,
rosters of 2/3/4 and every ordered last pair: 80 cases, preserving the point,
survival state, conceded details and ball generation after terminal victory.

Goal Guard suite: 544 assertions passed; compilation: 441 scripts passed.
Logs `/tmp/kras-keeper-inherited-terminal.stdout` and
`/tmp/kras-cover-scale-compile.stdout` passed strict guards.

## Open gates

The projectile-render stall and independent Storm Heart AI-balance warning
remain unresolved. Current GitHub runs 37877401757 and 37877408528 still
target ba2ada7, not this source; their source-relative results must be kept
separate. Physical-device frame pacing/energy/temperature, production
migration/deployment, full final-source regression and a fresh local Xcode 27
archive still require verification. No Apple upload or review occurred.
