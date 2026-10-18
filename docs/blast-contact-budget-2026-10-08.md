# Blast Ball: reserve time to physical contact

Parent source: `c25d6a0349af8123c49e391cf77528eb5e70f9a2` on
`feature/kras-online-random-rotation`. This is a local Godot repair, not
a native archive, production deployment or review submission.

## Reproduced defect and repair

The approach planner subtracted the three-metre attack range from its travel
distance. Blast Ball deflection requires actual body contact, so the planner
could commit when the remaining fuse covered escape but not the approach.
Added a boundary regression: an observed ball 2.5 metres away, a fuse only
0.05 seconds above the calculated escape reserve, visible radius 0.62.
Original code: 379 assertions passed and this assertion failed.

Travel allowance now uses the delayed visible ball radius plus the player's
own capsule radius and scale. It does not read private ball momentum or fuse.
Absent radius conservatively reserves extra approach time. No profile speed,
reaction time, physics, fuse duration or acceptance threshold was changed.

The previous positive fixture incorrectly assumed an eight-metre approach
with a five-second fuse was viable for its five-unit nominal speed. That case
now explicitly verifies retreat. The positive fixture retains the authored
five-second fuse and verifies an actually reachable four-metre approach.
Final Blast suite: 381 assertions passed. All 430 scripts compile. Strict
test, compile and natural simulation log guards passed.

## Independent natural sample

Official Godot 4.7.1 stable, offset 4100000, 24 baseline matches, 16 mirrored
seed/character difficulty comparisons and two stress matches: all complete.
Start/end simulation fingerprint agree:
`b90edfc4d8fb5f0b42fa8063f41e564f252a0c9f40ea09e2f3e2db1fa990d553`.
Raw report: `qa/blast-contact-budget-2026-10-08/report.json`.

Expert edge is 0.49375 and retains `expert bots no better than easy`.
Both mutated and chaos smoke matches passed. This validates a specific
planning correction, not balanced difficulty or representative device QA.
The prior offset-4000000 campaign used a different gameplay fingerprint;
its all-39 completion must not be relabeled as current-source qualification.
No source changed during this sample. Broader regression, balance diagnosis,
device/performance and release gates remain open.
