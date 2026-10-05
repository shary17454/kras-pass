# Terrain Road Query Qualification

Final implementation: `06588bc782bf783ddc440f9bf0c4dbb4d6c6ff90`.
Parent implementation: `8d68b52a15ac8328914f8874b0cf9179020f9945`.

## Change

Natural valley terrain repeatedly projects vertices onto the authored road.
Cache conservative X/Z bounds for consecutive groups of eight segments and
skip a group only when its minimum possible squared distance exceeds the
current best. Segment projection, interpolation and strict first-tie ordering
remain unchanged. Bounds include the wraparound endpoint and rounding margin.
No terrain vertices, materials, textures, road widths or collision faces are
removed. No save, network protocol or game rules change.

Packed arrays alias rather than providing an independent cache snapshot.
Store `points.duplicate()` as the cache key so in-place route edits trigger
fresh bounds. Reference: [Godot PackedVector3Array documentation](https://docs.godotengine.org/en/stable/classes/class_packedvector3array.html).

## Evidence

Godot 4.7.1, local macOS, isolated save directories and explicit logs:

| Check | Result | Log |
| --- | --- | --- |
| Cache invalidation regression before snapshot fix | 3,854 passed, 1 failed | `/tmp/kras-road-query-cache-red.log` |
| Final boundary/cache regression | 3,855 assertions passed, exit 0 | `/tmp/kras-road-query-boundaries-copy.log` |
| Final complete terrain-grid equivalence | 324,172 assertions passed, exit 0 | `/tmp/kras-road-query-full-grid-final.log` |
| Actual eight-world road/structure/collision regression | 5,853 assertions passed, exit 0 | `/tmp/kras-road-query-geometry-final.log` |
| Compilation | 353 scripts passed, exit 0 | `/tmp/kras-road-query-compile-final.log` |

Completed-summary and runtime/leak guards passed for all final logs. The
boundary suite includes near-endpoint rounding, double-precision query
inputs, crossing roads at different heights, ties across groups, actual
in-place route edits and replacement with an empty route. The stricter red
test first proves the actual route changed before asserting cache refresh.
It exposed an alias bug; the assertion was not relaxed to obtain a pass.

The complete comparison covers each 201 x 201 terrain vertex and authored
road endpoint on all eight armed-race routes. The baseline fixture preserves
the previous Node-based implementation and its arena-property reads. Results
compare exact distance and interpolated height, not an approximate tolerance.

Final one-pass sequential benchmark: original 56,153,926 microseconds;
optimized 10,555,347 microseconds (about 5.32 times faster for this function).
Total test wall time: 69.4 seconds. This shared-Mac microbenchmark is not
overall world load time, gameplay FPS, GPU performance, iPhone thermal behavior
or battery life. Earlier timings before the cache fix are not final evidence.

The geometry-only entry point calls the existing integration test unchanged:
it constructs all eight arenas, checks actual road/shoulder raycasts, bridge
excavation, tunnel collision, authored landmarks, weather behavior and surface
normal assets. It completed in 128.5 seconds; it does not run complete races.
The default integration suite still follows its previous full path.

## Release Gates

This work is on a feature branch, not merged into `main`. Full CI, physical
iPhone/iPad gameplay, natural-round balance, coordinated Railway deployment,
and an exact-source signed Distribution archive remain separate gates.
No App Store upload or review submission is evidenced by these tests.
