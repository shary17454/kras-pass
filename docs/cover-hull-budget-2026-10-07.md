# Rock Cover Hull Budget Investigation

## Source and Scope

Base: `1d0af27ce90a395396b12df3bac9583383cb5b0b`.
Branch: `perf/kras-cover-hull-budget`.
Only optional terrain-test diagnostics changed. Production rock geometry, terrain,
vehicle collision, rendering, and distribution archives remain unchanged.

## Rejected Candidates

The six authored rock meshes generate original convex shapes with
197, 266, 296, 328, 342, and 738 vertices.

- Default Godot simplification, 32 vertices: sampled support boundaries changed
  by up to 0.38038 m inward and 0.20587 m outward. Rejected.
- Configurable convex decomposition with 64 vertices, resolution 100000, and
  approximation disabled: boundaries still shifted materially. Rejected.
- 128 vertices, resolution 1000000, approximation disabled: sampled deviations
  reached 0.15319 m inward and 0.20123 m outward. Rejected.
- Greedy subset selection with a 128-vertex budget and a 0.025 m sampled target:
  full vertex physics queries found points farther than 0.05 m from candidates.
  Rejected; directional samples alone did not certify surface coverage.
- Subset selection with a 192-vertex budget and 0.01 m sampled target: four
  mesh/arena combinations initially failed the same coverage check. Testing the
  original shapes as controls produced zero misses. Rejected without repair.

## Repaired Subset Probe

The diagnostic selects extreme vertices from the ORIGINAL convex shape using
2112 directions. Godot's ConvexPolygonShape3D receives those unchanged vertices;
no custom collision engine or copied assets are introduced.

Each candidate is placed in the actual physics world at its tested cover scale,
on a dedicated collision layer. A sphere of radius 0.05 m is queried at EVERY
original hull vertex after two physics frames. Missing vertices are added to
the candidate, with up to three repair passes followed by a final check.
Every stored candidate vertex is also required to occur exactly in the original
vertex array. No assertion about production geometry has been relaxed.

Across the three current arenas, the final candidates contained 103-193 vertices.
All original vertices passed the 0.05 m physics query. Sampled support expansion
was zero; sampled inward deviations were at most 0.012524 m.

These are actual engine-query measurements, not a claim of mathematical precision
independent of the engine's numerical tolerances. The 192 selection budget can
be exceeded by repair; final counts are reported explicitly.

Command:

```sh
/opt/homebrew/bin/godot --headless --fixed-fps 60 --path . \
  --log-file /tmp/kras-cover-subset-repaired-engine.log \
  tests/test_runner.tscn -- --suite=tank_terrain \
  --test-data-dir=/tmp/kras-cover-subset-repaired-save \
  --cover-hull-probe --cover-subset-vertices=192
```

Result: exit 0, 3016 assertions passed. The project log guard also passed.
Evidence: `/tmp/kras-cover-subset-repaired.log`.
Earlier rejected runs remain in `/tmp/kras-cover-hull-{probe,64,128}.log`,
`/tmp/kras-cover-subset-128.log`, `/tmp/kras-cover-subset-192.log`, and
`/tmp/kras-cover-subset-control.log`.

The unchanged default terrain suite passed 253 assertions with exit 0 in
`/tmp/kras-cover-default.log`. Compilation passed for 413 scripts with exit 0 in
`/tmp/kras-cover-compile.log`. Both passed the project log guard and `git diff
--check` passed. Logs contain the known macOS system CA certificate retrieval
error (`get_system_ca_certificates`); no GDScript error occurred. This is not a
claim that the logs contain no error text or that network certificate trust has
been qualified. The complete suite was not rerun for this diagnostic-only change.

## Remaining Acceptance Gates

This probe is NOT enabled in gameplay and is not an FPS improvement yet.
Before production adoption:

1. Generate reproducible cached hulls at the largest authored scale per mesh,
   retain source identity, and validate all cover instances and orientations.
2. Exercise real vehicle contacts, sliding, projectiles, visibility/raycast
   occlusion, and navigation around every cover type.
3. Compare repeated isolated rendered four-human runs against unchanged source;
   verify frame percentiles and physics stalls, not only average FPS.
4. Run the complete regression/stability suite on accepted runtime changes.
5. Qualify the final source on actual iPhone/iPad before release claims.

No archive upload, review submission, or production Railway deployment is
established by these diagnostics.
