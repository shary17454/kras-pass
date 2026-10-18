# Source-Verified Baked Rock Hulls

Runtime candidate: `189f97605367bbe58153b7cafe29b004a4444866`.
Base: `083acaf1f059e1c624b63d8105625826289a4dc5` (PR 175).
Branch: `perf/kras-baked-cover-hulls`. No automatic main merge.

## Implementation

- Six precomputed ConvexPolygonShape3D resources in `data/collision`.
- Every retained point belongs exactly to the original mesh-generated hull.
- Baking uses the largest current authored width, 8.2 m, for every mesh.
- Every original vertex is checked with a 0.05 m sphere in the actual engine;
  failed vertices are restored before saving. All three arenas are validated.
- SHA-256 of original mesh vertex buffers is embedded in each resource.
- `cover_hull_cache.gd` checks that signature before use. Missing resources or
  modified source geometry use the original generated convex shape.
- Each mesh still shares one immutable collision shape within its battlefield.
- Actual collider offset, scale, rotation, cover count, road graph, and terrain
  triangles remain unchanged. Rendered rock meshes and materials are untouched.
- `--original-cover-hulls` provides an explicit original-geometry control.
- Soak reports record actual per-cover vertex counts and source signatures.

Final baked hulls contain 104-193 points, compared with 197-738 originally.
The default physical terrain suite passed 3121 assertions before adding the
changed-source fallback assertion. The bake passed 3073 assertions. A subsequent
full check is required for the runtime commit above.

## Full Qualification

`env GODOT_BIN=/opt/homebrew/bin/godot sh tools/check_party.sh` completed with
exit 0 on runtime commit `189f97605367bbe58153b7cafe29b004a4444866`:

- 414 scripts compile.
- 513 resources, 22 autoloads, 27 routes, eight characters: zero inventory issues.
- 388508 assertions pass in 347.5 seconds.
- Separate three-lap party race regression passes.
- Six separate boss/AI regression runs pass.
- Stability: all 39 matches pass, zero failures.
- After cache release and five settling seconds, retained material, mesh,
  texture, and audio PCM caches report zero.

Combined log: `/tmp/kras-baked-cover-full.log`.
Individual logs and isolated saves:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.LYpuXq`.
All project log guards passed. Logs still contain the known macOS system CA
retrieval error; this is not a claim that every log is textually error-free or
that network trust is qualified. No GDScript failure was reported.
Tracked runtime/test/data/project files remained unchanged after qualification;
this document is the only subsequent addition. This short cache-release check
does not establish absence of long-session or iOS memory leaks.

Rebaking command (also performs coverage and exact original-point membership):

```sh
/opt/homebrew/bin/godot --headless --fixed-fps 60 --path . \
  tests/test_runner.tscn -- --suite=tank_terrain \
  --test-data-dir=/tmp/kras-cover-rebake-save \
  --cover-hull-probe --cover-subset-vertices=192 --bake-cover-hulls
```

Changes to the authored maximum scale require rebaking and requalification;
source signatures alone do not qualify a larger collision scale.

## Sequential Rendered Comparisons

Godot 4.7.1, Metal Mobile on Apple M5, 1280x720 window, HIGH quality (2), cap 60,
four scripted human touch input sources, four personal views, no Bots.
Three live warm-up seconds followed by 30 measured seconds per run. No owned
headless qualification process overlapped these four measurements.

| Run | FPS | p95 ms | p99 ms | Worst frame ms | Max fighter physics ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original first | 54.266 | 27.958 | 38.982 | 77.629 | 32.812 |
| Baked first | 51.762 | 32.576 | 48.013 | 90.112 | 15.358 |
| Original repeat | 34.814 | 82.335 | 170.090 | 314.249 | 31.850 |
| Baked repeat | 55.933 | 22.112 | 31.031 | 59.579 | 17.255 |

All four exited 0, completed the requested duration, passed log guards, and
returned to 51 nodes after teardown. Raw reports are committed as
`cover-hulls-{original,baked}-{first,repeat}.json` in this directory.

The longest measured fighter interval was lower in both baked runs. However,
the first baked run had worse average FPS and frame percentiles than its
original control; run-to-run variability is significant. These samples do NOT
prove uniformly improved FPS, sustained 60 FPS, or device battery/thermal
performance. Different collision outcomes can also change the driving workload.
The change remains a reviewable development candidate, not a release acceptance.

The initial sandboxed render process failed to initialize macOS graphical
services, created no engine log, and had zero measured samples. It was terminated
before the local-session comparison; it is not included as a performance result.
Other user processes were read for diagnostic context but were NOT terminated.

## Release Gates Still Open

- Current-source natural balance/playability qualification of all 39 games.
- Repeated longer rendered runs and real touch/gamepad device QA.
- iPhone/iPad portrait/landscape, sustained FPS, memory, heat, and battery checks.
- Original Bundle ID native Release connectivity, authentication, and purchases.
- Approved source promotion and protected Railway protocol/deployment gates.
- Fresh final-source LOCAL Xcode 27 archive, signing, upload, processing, and
  App Review selection/submission. Previous candidate 109 is not this source.

No App Store upload or review submission is claimed here.
