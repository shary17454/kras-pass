# Four local tank views with ordinary weapon input

Parent source: `bc06021326b5a4f9fe736c8655480f349cf84416`.
This change extends only the performance fixture and its regression tests.
Gameplay, terrain collision, ammunition, cooldowns and health are unchanged.

## Workload

`tests/soak_perf.gd --fire` adds staggered 120 ms attack pulses every 900 ms
to ordinary scripted touch driving. It requires local tank input slots.
The fixture does not grant items or ammunition, aim at hidden opponents,
restore health, force respawns or bypass any firing rule. A completed firing
sample must observe a live projectile to exit successfully. This is not a
claim that all weapon varieties or four real human players were exercised.

## Results

Godot 4.7.1, macOS Apple M5, Mobile Metal renderer, 1280x720, quality 2,
60 FPS cap, tank_foundry, four personal views, four scripted human slots.
Both runs completed 60 steady seconds plus three warmup seconds. No local
unit or compile process ran concurrently with the rendered measurements.

| Workload | Mean FPS | p95 ms | p99 ms | Worst ms | Frames >50 ms | Active weapons peak |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Driving only | 60.0009 | 17.972 | 19.620 | 24.581 | 0 | 0 |
| Driving and firing | 58.0162 | 18.528 | 35.178 | 125.070 | 17 | 8 |

These sequential samples follow different actual collision trajectories;
they are not a controlled attribution of the stalls to any single operation.
The firing sample had four intervals above 100 ms. Worst retained intervals
were focused and had no pipeline compilations. Physics/process monitor
values are not exclusive CPU or GPU timings and do not prove causation.

The earlier parent-source 43.8921 FPS sample remains negative evidence.
The new drive-only result does not justify claiming a terrain optimization;
no terrain code was changed. The firing result does not meet a stable
60 FPS acceptance gate. Device performance, temperature and energy remain
unqualified.

Both rendered logs passed strict runtime guards. Nodes returned to 51.
Final fixture suite: 114 assertions passed. Compilation: 440 scripts passed.

Evidence:
`/tmp/kras-collision-baseline.{stdout,json,png}`,
`/tmp/kras-soak-firing-rendered.{stdout,json,png}`,
`/tmp/kras-soak-firing-unit-final.stdout`,
`/tmp/kras-soak-firing-compile.stdout`.

## Other release gates observed

GitHub source `ba2ada7c10ce0916f8d499895ff9164380c97150`:
run 37877401757 core job and six listed network jobs succeeded while
the remaining matrix was live. Run 37877408528 storm_heart simulation
failed: two ordinary runs scored nothing; mutated and chaos smoke passed.
The completed original artifact is retained at
`/tmp/kras-ba2-storm-failed-ci/`. This failure must not be suppressed or
relabelled READY. Other campaign jobs remained live. No workflow restart,
production deployment, main merge, Apple upload or review occurred here.
