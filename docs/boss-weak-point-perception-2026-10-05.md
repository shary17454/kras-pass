# Boss Weak Point Perception

## Scope and Source

Runtime source: `145f4f52b40bc4f0399a06a01b05d1da77c003d7`.
Branch: `fix/kras-boss-weak-point-perception`, based on main
`049e66019a4a8a8c41e9bdbc2262505c1741234b`.

The generic boss-hunter weak-point path previously consumed current positions
directly from `weak_points()`. Dreadnought vents and Sovereign core/orb targets
now expose the actual rendered nodes through `weak_point_nodes()`. The legacy
position interface remains available and Sovereign derives it from the same
objective selection, preserving shield/recovery/returned-orb rules.

The hunter uses shared camera, visibility and world-occlusion checks. Both
acquisition and moving target positions come from delayed visible samples.
Hidden, offscreen, deleted or closed objectives lose their observation history;
reappearance must earn a fresh reaction delay. Per-cue history is bounded by
the existing 32-sample limit and reset at round start.

No movement, damage, difficulty profiles, win conditions or networking wire
format were changed. This patch does not qualify Colossus `attack_plan()` or
Forge `feeding_plan()` perception; their specialized plans remain separate
outstanding review work. It is not a claim of all-agent fair perception.

## Tests

The initial focused test on the old runtime exited one: two missing-observation
interface assertions failed. `/tmp/kras-weak-points-before.log` records this
failure. It does not record an old-runtime hidden-target behavioral test.

Final focused suite: 36 assertions passed, exit zero,
`/tmp/kras-weak-points-decision.log`. Actual constructed boss scenes verify
visible target acquisition, the exact reaction boundary, delayed movement,
hide/reappearance, offscreen rejection, round reset and bounded history.
The actual `decide()` path attacks a reachable observed point and does not
attack that point when hidden. Sovereign tests preserve the positional
interface, shield/recovery constraints and independent orb acquisition and
return. These are controlled fixtures, not physical rendered playtests.

Full `tools/check_party.sh` ran from the committed runtime and exited zero:

- 368 scripts compiled.
- Inventory: 408 resources, 21 autoloads, 27 routes, eight characters, zero issues.
- Full test runner: 359803 assertions passed in 163.6 seconds.
- Actual race: all four AI racers completed three laps.
- Colossus seeds 345, 9614 and 172: defeated; PASS.
- Forge, Dreadnought and Sovereign seed 9614: defeated; PASS.
- Single-cycle stability: all 39 games, zero failures.

Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.WKNfkX/`.
The wrapper checks all step logs for engine errors. The stability cache warning
is intentionally invoked by the QA tool, not an actual OS pressure event.

## Production and Release Gates

No merge to main, production setting change or Apple submission was performed
for this patch. Railway deployment `574f7937-8d0b-4875-829f-a356f2b6781d`,
for existing main `049e66019a4a8a8c41e9bdbc2262505c1741234b`, remained BUILDING
in direct API inspection. Its status timestamp was 2026-10-05T14:45:49.450Z,
diagnosis null, instances empty, and direct `buildLogs(limit:100)` returned an
empty list. Incomplete observations did not trigger a restart or duplicate build.

Remaining gates include specialized boss plans and other-agent perception,
representative multi-seed/character/arena balance, physical device controls,
performance/thermal/battery and visual QA, all-game Internet qualification,
current production deployment qualification, and exact-source Distribution
archive/sign/validate/upload/process/review. Narrow passing probes do not
complete the full product goal.
