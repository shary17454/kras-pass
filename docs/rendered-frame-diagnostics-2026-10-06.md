# Rendered Frame Diagnostics

Runtime source: `bf87853c3cb7b063e1c74a7648e40fc7a4928d95`.
Branch: `perf/kras-rendered-frame-diagnostics`, stacked on camera PR 105.
No automatic main merge, iOS build, Archive, upload or Apple review.

## Changes

The rendered soak runner now retains at most eight worst steady frames, including
frame identity, focus state, sampled process/physics monitors, and per-observation
pipeline compilation deltas. Invalid and normal intervals are excluded; nested
measurement dictionaries are copied. Aggregate live pipeline counts and the
existing bounded operation trace are included in its JSON report.
Operation aggregates reset when live gameplay starts, excluding setup.

Camera updates and match HUD updates now have opt-in operation intervals using
the existing debug-only policy. Clocks and records remain disabled without an
explicit debug `--operation-trace`. Camera early returns are inside an update
helper so they cannot leave a started interval unfinished. No gameplay rules,
graphics quality or content were removed to increase measured FPS.

## Frozen-Source Observation

Godot 4.7.1, macOS Apple M5, Metal mobile renderer, 720 x 1280, quality 2,
60 cap, four Expert bots and a synthetic touch overlay. Seed 72; tag_hunt on
star_meadow. Capture completed 28 live seconds, all four bots moved, and nodes
returned 50 to 50. No concurrent test process was launched during this capture.
Log guard passed: `/tmp/kras-frame-diagnostics-pipeline.log`.
Report: `/tmp/kras-frame-diagnostics-pipeline.json`.

- Steady 25.02 seconds: 57.68 FPS, p95 17.812 ms, p99 21.544 ms.
- Worst steady frame 473.507 ms; five frames exceeded 100 ms.
- Camera maximum inclusive interval: 1.448 ms.
- HUD maximum inclusive interval: 104.138 ms.
- Fighter maximum inclusive interval: 94.706 ms.
- Maximum live-tick interval: 94.937 ms, which includes fighter time.
- Retained slow frames were focused. Pipeline deltas in all eight retained
  samples were zero; total live compilations still included two draw,
  two specialization and four surface compilations.

This does not prove the cause of every stall. Intervals are script wall time,
not exclusive CPU time, and may include scheduling/synchronization waits.
Performance monitors are sampled aggregate values, not exact costs of the
retained frame. Pipeline observations can lag asynchronous work. The zero deltas
do not prove that all GPU or shader activity is irrelevant. Do not add nested
interval totals or treat these macOS measurements as physical phone evidence.

Next diagnostic work should split fighter update and HUD suboperations and
correlate the repeated physics-frame events with rendering/system profiling.
Quality must not be lowered merely to hide this unresolved release gate.

## Checks

20 performance-sampler assertions, 18 operation-trace assertions and 691 camera
assertions passed. Logs: `/tmp/kras-frame-sampler-tests.log`,
`/tmp/kras-frame-diag-operation-tests.log`, `/tmp/kras-frame-diag-camera-tests.log`.
All 388 scripts compile: `/tmp/kras-frame-diag-compile.log`.
Log guards allow the known sandbox system-CA lookup error, not gameplay errors.
`git diff --check` passed. A full regression was not run on this source.

The previous diagnostic runs `/tmp/kras-frame-diagnostics.json` and
`/tmp/kras-frame-diagnostics-expanded.json` preceded the frozen commit and are
exploratory, not a claimed before/after optimization benchmark. The instrumentation
is diagnostic progress, not a completed hitch fix or a release qualification.
Physical iPhone/iPad performance, heat, battery and full release gates remain
open. Final Apple work remains local Xcode 27, not Xcode Cloud.
