# Rendered performance probe qualification

## Scope and source

The probe changes are based on `376d87b045f8f15ab6587c33235279fa4eca29d0`
plus the sampling-budget changes in this commit. The gameplay source includes
the screen-transition recovery and preceding stacked fixes; this is not `main`
and is not an App Store build. These changes affect testing only, not gameplay
physics, graphics quality, the shipping frame cap, or player saves.

## Corrections

- Reject headless execution rather than reporting simulated frame rates as GPU evidence.
- Report synchronous scene setup separately from post-setup wall time.
- Require at least ten live physics seconds and 400 post-warmup rendered samples.
- Warm up for one simulation second instead of 60 potentially very fast draw frames.
- Record each competitor's maximum displacement from its initial live position.
- Keep the post-setup 25-second wall ceiling and report early endings/timeouts without restarting matches.
- Exit unsuccessfully if no post-warmup samples were collected.
- Shut down and drain the shared audio bank before exiting the probe.

The wall ceiling cannot interrupt synchronous scene setup. A short survival
round can legitimately end before the full sampling budget; its reported
`full_sample_budget` must not be interpreted as true. Displacement confirms
movement, not successful AI completion or balanced gameplay.

## Measured rendered run

Command from the isolated checkout:

```sh
/opt/homebrew/bin/godot --path . --rendering-method mobile --audio-driver Dummy \
  --log-file /tmp/kras-perf-live-budget.log tests/perf.tscn -- \
  --test-data-dir=/tmp/kras-perf-live-budget-save \
  --games=tank_arena,sabaq_sawarikh --screenshots
```

Environment: Godot 4.7.1 official, macOS, Apple M5, Metal 4 Forward Mobile,
1920x1080, uncapped rendering, four Expert bots, seed 11, isolated test saves.

| Game | Setup ms | Live simulation s | Samples | Mean ms | p95 ms | Worst ms | Godot static MB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tank_arena | 3848 | 10.00 | 939 | 9.59 | 13.06 | 59.86 | 367.7 |
| sabaq_sawarikh | 2031 | 10.00 | 1561 | 5.77 | 16.02 | 142.94 | 371.7 |

Both report the full budget. Per-slot maximum displacement:

- Tank: 60.98, 51.79, 23.33, 21.93 world units.
- Race: 113.14, 104.28, 106.16, 91.92 world units.

The process exited 0; the existing runtime log guard passed. Nodes returned
to 49 (initially 49), and the log contains no ObjectDB/resource leak warning.
Screenshots `/tmp/kras-perf-tank_arena.png` and
`/tmp/kras-perf-sabaq_sawarikh.png` were visually inspected: rendered worlds,
visible competitors, and readable landscape HUD. This does not certify other
arenas, portrait layouts, touch controls, or all 39 games.

## Regression evidence

`tests/suites/test_perf_sampling.gd` checks that neither a fast frame count nor
simulation time alone satisfies the budget, including the 9.999-second boundary.
The initial focused runner passed 5 assertions including its suite-loading
assertion (`/tmp/kras-perf-budget-tests-final.log`). Additional assertions cover
early-round termination and the wall-clock ceiling. The final runner passed
9 assertions (`/tmp/kras-perf-budget-regression.log`), and its log guard passed.
The rendered measurements preceded the pure `_should_finish` extraction;
the final unit checks cover that unchanged termination condition.

The rendered `rising_tide` run did not end early on this seed: it reached ten
simulation seconds and 2516 samples, with mean 3.58 ms, p95 12.28 ms and worst
132.58 ms (`/tmp/kras-perf-short-round.log`). It is not claimed as a rendered
early-ending reproduction. A separate headless invocation exited 1 with the
explicit rendered-window refusal (`/tmp/kras-perf-headless-budget.log`); this
expected refusal is not a gameplay failure or a passed graphics benchmark.

The compile check passed all 338 scripts (`/tmp/kras-perf-budget-compile.log`)
before the small termination-helper extraction. The final compile check also
passed all 338 scripts and its log guard
(`/tmp/kras-perf-budget-final-compile.log`).

The preceding probe run reported two ObjectDB instances leaked at exit despite
returning to the initial scene-node count. Adding audio shutdown/drain removed
that warning in a subsequent verbose rendered run
(`/tmp/kras-current-rendered-perf-final.log`). Node-count equality alone was not
used to claim leak-free execution.

## Open release gates

The averages do not erase 60/143 ms frame spikes. Setup still blocks for seconds.
These are brief measurements on a shared Mac, not controlled device benchmarks
or evidence of a runtime optimization. Godot static memory is not total process
or GPU memory. Audio uses the Dummy driver, so audibility is not tested.

Physical iPhone/iPad frame pacing, sustained battery/thermal behavior, tournament
asset preloading, all-map/orientation QA, complete network CI, exact-source signed
Distribution archive, upload/processing, and App Review submission remain open.
Do not enable production multiplayer or submit an iOS release from this evidence.
