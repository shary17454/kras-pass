# Memory Cache Attribution Qualification

## Source and Method

- Parent: b89836f896da159f5456a719c737e070297c01aa, PR 78.
- Final tested source: b8b800e91362c62b2357db8cb9d9883cfb082951.
- QA-only changes in `tests/stage_zero_stability.gd`: snapshot baseline and per-cycle static memory, objects/resources, mesh/material/texture cache counts and unique cached audio PCM bytes. Observe memory immediately after cache clearing and after five actual wall-clock seconds with the event loop running.
- Existing post-warmup 16 MiB gate and match lifecycle checks remain unchanged. Add a failure if any graphics cache remains populated after the warning handler.
- Three cycles: 117 real match lifecycles, four AI, all 39 default arenas, seeds 250925/251922/252919. Timed rounds shortened; race laps unchanged. Godot 4.7.1 official, desktop macOS headless, fixed simulation ticks. This is not a device FPS test.
- Headless AudioManager disables playback and synthesis, so cached PCM remained zero. This cannot qualify active-audio memory on a real device.

## Results

| Measurement | Static Bytes | Materials | Textures | Meshes |
| --- | ---: | ---: | ---: | ---: |
| Before any match | 33553026 | 0 | 0 | 0 |
| Cycle 1 complete | 555515556 | 512 | 254 | 258 |
| Cycle 2 complete | 557703160 | 525 | 259 | 258 |
| Cycle 3 complete | 558403524 | 526 | 259 | 258 |
| Before warning | 558404592 | 526 | 259 | 258 |
| After warning | 442138076 | 0 | 0 | 0 |
| Five wall-clock seconds later | 442136788 | 0 | 0 | 0 |

- Engine exit 0: 117 matches, zero failures. Post-warmup growth 700364 bytes, below the unchanged gate.
- Clearing the graphics caches released 116267804 tracked bytes after settling, approximately 111 MiB. It did not return the process to its approximately 32 MiB baseline; approximately 422 MiB remained.
- No match objects, orphan nodes, input ownership or global signal leaks were reported by the existing lifecycle checks. The residual static memory has not been assigned to a specific owner. Reading shared font/theme caches suggests further inspection, not proven attribution.
- Compile: 366 scripts passed; log scans found no script/native errors or resource-leak exit warnings.

## Evidence and Limits

Final report: `/tmp/kras-memory-attribution-settled/stability.json`, SHA256 `2ce679ad1a9ec5cb7090591fdf7ef458925aa5d2c227db6295ae52b32ec8eefb`. Log: `/tmp/kras-memory-attribution-settled.log`. Compile log: `/tmp/kras-memory-attribution-compile.log`.

Initial instrumentation source 0fdbdad8fe68f83762f49fbc5179931ca960a11c also completed 117 matches; `/tmp/kras-memory-attribution/stability.json`. It lacked the delayed observation and is not substituted for the final source.

OS.get_static_memory_usage is Godot's tracked static memory, not resident RSS, GPU allocation or iOS jetsam footprint. Do not infer sustained 60 FPS, acceptable phone memory, battery/thermal safety, zero leaks or complete attribution from these data. Actual-device/native allocator/font/render profiling and active-audio/replay workloads remain release gates.

No gameplay graphics downgrade, production merge/deploy, archive, Apple upload or submission was performed.
