# Shared vehicle edge braking

Status: TARGETED_REGRESSION_PASSED / FULL_SUITE_PASSED.
Stage 0 remains QA_PENDING / MERGE_PENDING. No balance or release acceptance.

## Proven Defect And Scope

Tank AI previously used a fixed two-metre edge check and called drive_to
without the braking override already implemented by the kart driver. Turning
toward safe ground can still request forward throttle while the vehicle's
momentum points outward. A controlled regression failed 384 brake-input
assertions on the original code: three tank maps, eight characters, all four
AI difficulties and four cardinal headings. The original test exited 1:
769 passed, 384 failed.

Extracted the existing kart stopping-distance logic into
AIBrain.retreat_drive_from_edge and called it from DriverBrain and TankBrain.
It uses the vehicle's own velocity, facing, acceleration and decision interval,
with the driver's existing speed-dependent safety margin. Ordinary drive
integration still applies all acceleration and braking; no teleport, impulse,
stat advantage or direct velocity override was added to the AI.

Changed production files:
- src/ai/ai_brain.gd: shared vehicle retreat/braking helper.
- src/ai/brains/driver_brain.gd: replace the original inline block with the helper.
- src/ai/brains/tank_brain.gd: use the shared retreat instead of the fixed margin.

Physics, scoring, weapons, maps, character stats and network protocol are
unchanged. This is not the rejected lateral shell-evasion candidate, which
remains outside the active source tree.

## Tests

Added tests/suites/test_tank_edge_braking.gd and registered it in the runner.
The original brake failures now pass, and existing inward escape throttle is
retained. Tests invoke Fighter._integrate_drive rather than a copied movement
formula to check reduction of outward speed. They do not prove complete edge
recovery trajectories or collision clearance under arbitrary impulses/modifiers.

A test-only legacy kart helper retains the pre-extraction equation. Across
2304 character/difficulty/speed/clearance/facing cases, the shared driver's
steering/throttle and RNG state match the reference exactly. Combined targeted
result: 5761 assertions, exit 0, strict log guard passed, 45.1 seconds.

One intermediate version freed the test scene before all characters completed;
Godot printed a partial success summary but also a SCRIPT ERROR. The strict log
guard correctly rejected it. Only the fixture lifetime was corrected; no
production threshold was changed to make that comparison pass.

Compile check: 461 scripts, exit 0, strict guard passed.
The first full suite exited 1 in 1290.1 seconds: 425349 passed, one failed.
The failure was the existing kart network test's lap/boost audio expectation.
An isolated ordinary run passed 121 assertions. A controlled 1001ms packet gap
reproduced the missing cues, showing that the test did not control the real-time
freshness boundary. This is consistent with the slow-host failure, though the
original failed run did not record the inter-packet timestamps.

The kart test now injects the existing receive_clock API. It checks that a
1000ms gap permits fresh cues, a 1001ms gap suppresses old cues, duplicates do
not resurrect them, and a later fresh boost still plays. Real boost generations
are asserted after pad cooldown expiry to avoid vacuous silence checks. The
expanded suite passed 129 assertions, exit 0, strict guard passed. No production
audio/network threshold was changed. A first added recovery case failed because
the pad was still cooling down; fixing its setup was not a production change.

Full suite rerun after that test-only fix: 425358 assertions, exit 0, 540.1
seconds, strict log guard passed. Gameplay fingerprint matched before and after
the run. No production/test/runtime edits occurred during either full-suite
execution. This proves the covered regressions, not phone or balance acceptance.

## Source And Evidence

Base commit: c226706fd425e66f5241945bf38155c8ce9d6f8f on
feature/kras-online-random-rotation. The isolated runtime derives from the
previous verified Git archive plus the exact edited files. Gameplay fingerprint:
`2f90389f023b6b1c6632a41917a78cdb90ef85013d6e2d61e5c073fcaffd02c4`.
Edited source/test file SHA256 values match between checkout and runtime:

- AIBrain: `24f50324b981b1835b05c4ba3b592b205d223ef7d1691e20afa3b38d90ffc5fc`.
- Driver: `c2f4ce94b4289ab6e411184a67d05856acfe3469b85e25e6834dad30a855f804`.
- Tank: `8b76efe36d6a2e409449ed4963681111bce40ac8d642005043045be843a9eea4`.
- Runner: `1458eac5bb73052ccd87ce9b639120cd90647f5ec6666e1a5aba3fe84c3d3aea`.
- Suite: `38062186c74cb7cf1a5b5c31071d22978c29ec353cbe2e6535a16d050c8805db`.
- Kart clock fixture: `aec217049bc163ccf68735ce808314feb6428f7db92afecd360f11494cbd1d4f`.

Original logs are /tmp/kras-tank-edge-red-2026-10-15.engine,
/tmp/kras-tank-edge-green-2026-10-15.engine,
/tmp/kras-tank-edge-equivalence-2026-10-15.engine (rejected),
/tmp/kras-tank-edge-equivalence-fixed-2026-10-15.engine,
/tmp/kras-edge-compile-2026-10-15.engine and /tmp/kras-edge-full-2026-10-15.engine.
Completed evidence is preserved outside Git at ../qualification-tank-edge-2026-10-15/,
including the rejected test runs, initial failed full suite and successful rerun.
Successful full-suite log SHA256:
`5849021e37518a5a30ae32b774f72355262bbb297ff0817ba82fa7ddcfa1ac7c`.

## Remaining Gates

The previous natural tank balance warnings remain unresolved. Natural-duration
matched and held-out campaigns on the changed source are still required; the
older 84d-source reports do not qualify this new behavior. No READY/DONE state
change, phone FPS/thermal/battery claim, main push, Railway deployment, signed
archive, Apple upload or review submission follows from these regression tests.
