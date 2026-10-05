# Compound Actor Observation

## Source and Defect

Runtime change: `8b373e2ff23e6d4397e952b8901c3021ce4cebac`.
Integrated test source: `d146799a633393da31b7754b069f0a1bedfe2952`.
Base production source: `01c5362dea176e86223548cacaec0332150e4323`.

`AIBrain.can_observe` previously accepted an actor origin before examining
rendered child geometry. A visible Node3D root could expose an actor even when
its mesh or visual container was hidden, its layer was excluded by the camera,
or its child geometry was outside the frame. Camera-free simulations also
accepted entirely hidden compound actors.

Observation now uses rendered body-part positions and mesh bounds rather than
unrendered compound origins. Visible alternative parts remain cues. Queued
nodes are excluded. Traversal and rays remain bounded independently to 32 nodes
and 12 candidate points; an exhausted hierarchy is not classified as
geometry-free. Authored geometry-free logical markers retain their existing
visibility, camera-frame and world-occlusion contract.

This does not change character movement, AI difficulty parameters, RNG,
network protocol, match scoring or production flags. It does not prove every
material-opacity, particle-emission or custom logical-marker contract matches
what a human sees; those remain further perception-review work.

## Behavioral Tests

- `/tmp/kras-compound-visible-before.log`: eight passed, five failed before
  the runtime fix. Failures reproduced hidden mesh/container, excluded child
  layer, off-screen child geometry and camera-free hidden geometry.
- `/tmp/kras-compound-visible-final.log`: 14 assertions passed, including
  reappearance, alternate visible parts, inherited root hiding, logical
  markers and bounded deep-tree traversal.
- `/tmp/kras-compound-existing-visibility-final.log`: 2085 assertions passed.
- `/tmp/kras-compound-existing-occlusion-fixed.log`: 18 assertions passed.

The first integrated run exited one with 360135 passed and one failed assertion
(`/tmp/kras-compound-full-check.log`). The old ball test expected a hidden ball
observation containing radius zero, despite both sphere and fuse label being
hidden. It now requires an empty observation: stricter prevention of private
position/size information, not a relaxed accuracy or balance threshold.

## Final Integrated Checks

Godot 4.7.1 official `a13da4feb`, exact source `d146799`:
`tools/check_party.sh` exited zero.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.G0soFo`.
Wrapper log: `/tmp/kras-compound-full-final.log`.

- 372 scripts compile.
- Inventory: 412 resources, 21 autoloads, 27 routes, eight characters, zero
  inventory issues.
- 360136 assertions pass in 249.7 seconds.
- Three-lap real race and all six authored boss probes pass.
- One stability cycle: 39 matches, zero failures.
- Server tests with all six newly generated world captures: 192 pass, zero
  fail, zero skip (`/tmp/kras-compound-server-captures.log`).

## Matched Natural Sample

Same Ring Rumble seed offset 1200000: 24 baseline matches, 16 mirrored
difficulty samples and two mutator/chaos smokes complete before and after.
Reports: `/tmp/kras-ring-natural-01c5362/report.json` and
`/tmp/kras-ring-natural-8b373e2/report.json`.

Mean duration: 41.8549 to 41.8403 seconds. Wins by slot remain [4, 5, 6, 9].
Tie rate remains zero; expert place share changes from 0.56875 to 0.575.
This is not a win-rate metric or a large-sample balance certification. Both
reports have no flags for this small sample; earlier campaign flags and
physical acceptance requirements remain unresolved.

## Rendered Performance

Both runs used Metal 4.0 on Apple M5, macOS, 1280x720 and four moving Bots.
Each game completed at least ten live simulation seconds and 400 samples;
both returned to 50 nodes after teardown, matching the start count.

| Renderer | Game | Mean ms | P95 ms | Worst ms | Setup ms |
| --- | --- | ---: | ---: | ---: | ---: |
| Forward+ | tank_arena | 17.42 | 19.12 | 115.13 | 2573 |
| Forward+ | goal_guard | 16.67 | 17.07 | 24.73 | 690 |
| Forward+ | boss_forge | 16.95 | 17.27 | 121.69 | 62 |
| Mobile | tank_arena | 16.73 | 17.08 | 46.48 | 2390 |
| Mobile | goal_guard | 16.67 | 16.94 | 18.58 | 647 |
| Mobile | boss_forge | 17.08 | 17.16 | 122.26 | 50 |

Logs: `/tmp/kras-compound-rendered-d146799.log` and
`/tmp/kras-compound-mobile-d146799.log`; both pass the Godot log guard.
The final Forge screenshot was inspected: nonblank arena, four fighters,
Arabic HUD and live boss health. An unrendered health symbol and clustered
fighters are visible polish concerns, not automatically release-ready content.

These short Mac samples do not certify sustained 60/120 FPS, iOS GPU/RSS,
thermal or battery behavior. Frame spikes, synchronous tank construction,
physical QA and realistic content polish remain required. There is no
matched baseline performance claim or causal speedup claim for this fix.

## Release Boundary

This branch is not merged into main or deployed. It creates no signed archive
and performs no Apple upload, processing or App Review submission. Production
online remains disabled pending coordinated protocol and real-peer acceptance.
Keep the full product completion goal active; passing this regression does
not mark all 39 games READY or satisfy all release gates.
