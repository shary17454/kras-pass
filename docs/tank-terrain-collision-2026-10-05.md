# Tank Terrain Collision Qualification

## Defect and Fix

`natural_valley.gd::_terrain()` creates the rendered terrain, its triangle
collision and the `observation_mesh` reference used by AI visibility checks.
`tank_world.gd::build()` called that method, then cooked and installed an
identical triangle shape again. Godot automatically renamed the duplicate
node, so matching only the literal `TerrainCollision` node name concealed it.

The tank builder now keeps the shared terrain collider and does not construct
the second body or shape. Geometry resolution, triangle data, textures,
materials, terrain height, cover, road graph, weapon rules and network protocol
are unchanged. This removes redundant collision cooking and native physics
objects; it does not make the remaining synchronous world construction async.

Implementation source: `d5505dc07db28fb0933b6b11fbcbd4a12c5d9fd8`.

## Regression Evidence

The new test opens real matches on tank_foundry, tank_oasis and tank_frost.
It identifies colliders by their resolved observation geometry, not by their
potentially rewritten names. It verifies a single collider, exact mesh/collision
triangle equality, the observation reference, the 25-point connected road graph
and actual physics-ray contact at the authored ground height.

- Before the fix: 28 passed, 3 failed, each map had two terrain colliders.
  `/tmp/kras-tank-terrain-red.log` (exit 1).
- After the fix: 31 assertions passed.
  `/tmp/kras-tank-terrain-after.log` (exit 0, log guard passed).
- Existing tank network presentation/AI/projectile suite: 165 assertions passed.
  `/tmp/kras-tank-terrain-network.log` (exit 0, log guard passed).
- Compilation: all 349 scripts passed.
  `/tmp/kras-tank-terrain-compile.log` (exit 0, log guard passed).

The initial test-development run matched node names and omitted scene teardown;
its failures/leaks are retained in `/tmp/kras-tank-terrain-before.log`. It is not
accepted as qualification. The corrected red run cleans up and reproduces the
actual duplicate geometry on all three maps.

## Four-Process Network Run: Failed

`GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js
--game=tank_arena --humans=4 --seed=117` used four real Godot processes and a
real local WebSocket service, with separate isolated saves. Source was the
implementation commit above; no production scripts changed during the run.

The run exited 1 with `4-players-0 timeout`, the existing 180-second parent
deadline. The host progressed through the first round and into the second;
the peer logs show movement, weapon inventory, armor changes and received
snapshots. The service recorded a guest resume. There is no completed
`NETWORK_FINISHED` result, so scores, full reconnect recovery and successful
match completion are NOT qualified by this run.

Evidence: `/tmp/kras-tank-terrain-four-peer.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-QVZ9w5/`.
The final host frame-gap maximum was 8799 ms; server event-loop maximum was
2665 ms. These indicate severe scheduling/runtime gaps but do not prove their
cause or exclude a product defect. The smoke configuration still requires two
30-second simulated rounds. No timeout, gameplay duration or assertion was
relaxed to convert this failure into a pass. All owned local processes ended.

## Rendered Performance Evidence

Actual Metal Forward+ rendering on Apple M5, Godot 4.7.1, four AI competitors,
seed 11, tank_arena. Before/after comparison runs use separate new isolated save
directories with default settings. Both complete 400 sampled live frames and
more than 10 seconds of actual simulation; all competitors move. Neither run
uses fixed-fps acceleration. Both return to 50 nodes after scene teardown.

| Measurement | Before | After |
| --- | ---: | ---: |
| Resource preparation | 2551 ms | 1038 ms |
| Synchronous scene setup | 2917 ms | 3376 ms |
| Mean rendered frame | 25.72 ms | 29.88 ms |
| p95 rendered frame | 31.53 ms | 47.38 ms |
| Worst rendered frame | 71.72 ms | 99.55 ms |
| Actual simulation sampled | 11.27 s | 12.95 s |

Logs: `/tmp/kras-tank-terrain-perf-before-isolated.log` and
`/tmp/kras-tank-terrain-perf-after.log`. The rendered screenshot
`/tmp/kras-perf-tank_arena.png` was inspected: terrain, vehicle characters,
cover, weapon crates, HUD and minimap render. This is one landscape view on Mac,
not full orientation or iPhone visual QA.

These single shared-machine samples do NOT demonstrate a frame-time or loading
speed improvement. The after sample is slower. The confirmed gain is removal
of duplicate physical geometry, not achievement of 60 FPS. Cache state, live
combat and shared-machine load are not controlled sufficiently for causal
performance attribution. iPhone uses the Mobile renderer, unlike these Mac
Forward+ samples. Device frame pacing, battery and thermal qualification remain
open. No release, production deploy or App Store submission is claimed here.
