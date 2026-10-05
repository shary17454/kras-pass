# Live Memory Pressure Pool Qualification

## Confirmed Fault and Fix

`Platform._on_memory_warning()` called `Pool.drain()`, which removed factories, checked-out counts and peak metadata during an existing match. Later projectile/collectible allocation required those factories, registered only when the game was built. A warning could therefore stop further spawning while existing objects remained alive.

`Pool.trim_idle()` now queues only unused instances for deletion and clears their idle lists. Factories and checked-out bookkeeping remain available. Final match teardown still uses `drain()` to remove the complete pool. MeshFactory's cache-clear behavior is unchanged; resources still referenced by visible objects remain referenced by those objects.

## Evidence

- Parent: `d9a2b70fae4636e7cab3b5d026487601ad5bfe2f`, PR 77.
- Runtime fix: `33a1d231e777b3661ab7a400874ea64b2de55940`.
- Final tested source, including updated legacy contract test: `28765dcb96c4b2893328d07725f4c7b3fa85a218`.
- Before: `/tmp/kras-memory-pressure-before.log`, eight failed factory/count/spawn expectations in actual Turret Duel and Gem Grab scene fixtures. Constructed matches use real controllers and objects; physics is frozen to isolate the warning handler.
- Focused after: `/tmp/kras-memory-pressure-fixed.log`, 21 assertions passed. Existing objects survive deferred trimming; new projectiles and gems spawn; repeated warnings retain live counts; caches clear; final teardown removes pools.
- First full attempt: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.F9BKiN/`, 359765 passing assertions and one failure. The older systems test expected deletion of the entire pool; it now verifies idle removal, subsequent allocation and final teardown explicitly.
- Final `tools/check_party.sh`: exit zero, `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.7wFjVF/`.
- 366 compiled scripts, 405-resource inventory with zero issues; 359768 unit/integration assertions passed in 351.2 seconds.
- Real race regression and six natural boss-defeat probes passed. One-cycle lifecycle/cleanup stability: 39 matches, zero failures. The focused assertions overlap the full suite and are not added to its count.

## Limits and Release Gates

This fixes a demonstrated memory-warning correctness defect, not a measured reduction of total RAM. Short warning-fixture readings increased while active resources were still referenced; those asynchronous observations do not establish a memory saving or the cause of the earlier approximately 533 MiB desktop reading. No baseline-wide memory attribution, renderer/GPU profiling, actual iOS pressure callback, jetsam, thermal, battery or device FPS qualification was completed here.

Parent PR 77 independently passed CI core job 111801435755 in run 37321414919: logs identify intended source d9a2b70, 365 scripts, 359746 assertions, 117 stability matches and 192 actual-capture server tests passed. That source does not include this new fix and cannot qualify its CI. Full network matrix and original product/release scope remain incomplete.

No automatic merge, production Railway deploy, signed Distribution archive, upload, processing verification or Apple submission.
