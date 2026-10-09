# Tank Network Pilot Pursuit Qualification

## Failure And Scope

Run 37989337902 failed at source
`3c7e48ab1b09048c8893221db8101857c3d80137` in the restored two-human
tank final. The host recorded shots and inventory, but no armor change.
The pilot finished near the center while its surviving rival remained about
27 meters away. Its approach helper substituted the center whenever a rival
was outside 22 meters or occluded, despite the caller already providing a
road waypoint planner. This could strand pursuit at the center.

The helper now retains the rival as the route destination. Existing waypoint
navigation handles cover; firing range, chassis alignment, height checks,
armor/damage rules, round duration, and network acceptance checks are unchanged.
Only test automation changed. This is not a production AI or visual improvement.

## Local Evidence

Tests ran sequentially on `/tmp/kras-tank-pursuit-check`, extracted from the
clean parent commit, with the modified test files copied from the checkout.
This avoids the Documents File Provider read stalls. Godot 4.7.1 import
completed with exit 0 and a clean strict import-log check.

- Pursuit regression suite: 11 assertions, exit 0, strict test-log pass.
- Network unit suite: 420 assertions, exit 0, strict test-log pass.
- Compile check: 447 scripts, exit 0, strict log pass.
- Original failure scenario: `node network-smoke.js --game=tank_arena
  --tournament --humans=2 --tank-final-checkpoint`, exit 0. Both peers
  reported PASS, identical scores `[478,100,300,200]`, champion slot 0 and
  completed tournament after one tie attempt. The original armor observation
  requirement remained enabled. Both engine logs passed strict checks.
- `git diff --check` passed.

Evidence: `../qualification-tank-pursuit-2026-10-10/`.
Original failing artifacts remain at
`/tmp/kras-tank-failure-3c7e48a-37989337902/`; they are not replaced by the
passing rerun. Server timing and desktop test speed are not phone FPS,
thermal, or battery evidence.

## Separate Earlier-Source Campaign

Run 37970339411 completed successfully at
`d9841d2543f216bb1d989fd1dd7525e903c36d95`. Downloaded artifacts contain
40 matching clean checkout attestations, 542 clean engine logs, 542 completed
peer reports and 1204 round-history entries. These results are older-source
evidence, not qualification of current woodland terrain or the modified pilot.

## Remaining Gates

The complete current-source tank campaign and full regression still need
qualification. Other balance warnings, content polish, device multiplayer,
controller and sustained-performance QA, production data/deployment approval,
and a new exact-source signed archive remain open. No main promotion,
production deployment, Apple upload or review submission occurred here.
