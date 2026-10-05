# Forge Frame Attribution

## Exact Scope

Probe source: `b0cd4fd2d4a80d64339a7f2fccaa6f8117bd25fa`.
This branch extends the compound-actor AI review branch, not production main.
Only `tests/perf.gd` and its sampling test change; no gameplay rule, renderer
setting, network flag, asset, score or AI parameter is modified.

`--slow-frame-trace` records intervals at least 25 ms and retains the eight
worst samples, plus the total slow-frame count. Each retained measurement
contains simulation time, physics frame, Godot process/physics monitors,
draw calls, node count, static-memory accounting, phase and copied scores.
The trace is bounded and opt-in; it is not visible in the shipping game.

Pipeline counters cover canvas, mesh, surface, draw and specialization.
Deltas start before resource preparation, so totals include preparation and
loading as well as gameplay. Frame monitors and current scene state can lag
the interval; these measurements are correlated evidence, not CPU call stacks,
GPU timings or proof of a single causal function.

Official counter semantics:
[Godot RenderingServer documentation](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#enum-renderingserver-renderinginfo).
Actual enum availability was checked by compiling and running on Godot 4.7.1.

## Tests

- `/tmp/kras-frame-trace-final-policy.log`: 15 assertions pass. Covers the
  existing live-time/sample budget and new finite threshold, total count,
  eight-entry memory bound, worst-first ordering and independent score copies.
- `/tmp/kras-frame-trace-compile.log`: all 372 scripts compile.
- `/tmp/kras-forge-pipeline-trace.log`: rendered probe exits zero; the Godot
  error-log guard passes.
- The full 360136-assertion suite and 39-match stability run belong to parent
  source `d146799`, documented in `ai-compound-visual-cues-2026-10-05.md`.
  They were not rerun on this instrumentation-only source and are not claimed
  as a fresh full-suite result for it.

## Real Rendered Samples

Mac Apple M5, Metal 4.0 Mobile renderer, 1280x720, four moving Bots, same
Forge seed/configuration. Each repeat completed ten simulation seconds and
over 400 samples. No full-suite CPU workload was running concurrently.

| Probe | Repeat | Slow frames | Worst ms | Mean ms | P95 ms | Setup ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Initial bounded trace | 1 | 5 | 80.65 | 16.79 | 17.02 | 1409 |
| Initial bounded trace | 2 | 0 | 19.03 | 16.67 | 16.98 | 29 |
| Pipeline counters | 1 | 7 | 138.91 | 17.21 | 17.20 | 2573 |
| Pipeline counters | 2 | 5 | 50.14 | 16.76 | 17.23 | 108 |

Initial trace: `/tmp/kras-forge-slow-frame-trace.log` (source `8e32b76`).
Counter trace: `/tmp/kras-forge-pipeline-trace.log` (source `b0cd4fd`).
Both return to 50 nodes after teardown, matching their start count.

Counter run one reports canvas 2, mesh 0, surface 14, draw 11,
specialization 12 compilations since probe start. Its 2.12-second slow sample
already reports draw 10; subsequent samples report draw 11.
Run two reports zero in every pipeline counter but still has five intervals
at least 25 ms. Thus compilation occurs during initial use, but cannot explain
all observed frame spikes. Warm repeat results are variable; no causal speedup
or sustained 60 FPS certification follows from these short measurements.

## Concrete Follow-Up

`src/fx/burst.gd` says its shards return to a pool, but `configure` actually
creates `MeshFactory.box` nodes for every shard and `_process` frees the burst
at expiration. `MeshFactory.burst` constructs a new root each call; this path
does not use the Pool autoload. The shared mesh/material cache is not a node
pool. Forge's strike requests sixteen shards.

Fix the burst lifecycle using bounded real reuse, checking reset of velocity,
transform, age, colour and parent ownership, then exercise expiry, overlapping
bursts, teardown and memory-pressure trimming. Measure the same rendered
samples again; allocation reduction alone is not proof of the entire hitch
being solved. Also investigate first-use renderer preparation rather than
deleting caches, lowering visual quality or relaxing frame-time thresholds.

## Unresolved Release Gates

Performance spikes are not fixed by this probe. Physical iPhone/iPad frame
pacing, thermals, battery, RSS and GPU measurements remain necessary, along
with all outstanding balance/content/online/replay and signing/release gates.
No production change, merge, archive, upload or App Review submission occurs
on this branch. Keep the complete product objective active.
