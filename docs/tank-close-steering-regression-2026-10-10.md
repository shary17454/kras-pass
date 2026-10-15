# Tank Close-Steering Regression And Diagnostic Limit

Baseline source: `40c4f32` on `feature/kras-online-random-rotation`.
Godot 4.7.1 official. No runtime source, AI tuning, physics, damage, visibility,
balance thresholds or game rules were changed in this checkpoint.

The independent tank cohort's difficulty warning remains open. One suspected
cause was reverse-steering polarity when the tank stops to aim at a nearby
rival behind its facing. Tests did not reproduce that defect. Inspection
confirmed both drive-helper branches preserve the same steering polarity.
An unconfirmed hypothesis is not presented as a repaired gameplay bug.

## Added Regression

`tests/suites/test_tank_crate_perception.gd` now isolates close engagement
steering through the actual Tank brain and Fighter drive integration:

- Four difficulty profiles, four road headings and targets on both rear sides.
- Two distances distinguish muzzle-clearance reversal from stationary aiming.
- 64 configurations, two assertions each: yaw error decreases and the intended
  reverse/hold input remains intact.
- Accuracy is fixed to one for this deterministic polarity test only. Target
  selection, prediction, visibility and crate selection are fixture overrides;
  this does not attest live perception or difficulty separation.
- Existing delayed/occluded/reappearing crate tests remain unchanged and run
  after this test. Actual terrain and projectile interception are outside the
  new fixture's scope.

Final focused run: 221 assertions, exit 0, strict test log guard passed.
Separate Tank networking suite: 192 assertions, exit 0, strict guard passed.
These 413 assertions are not a complete regression suite or device acceptance.
The first unchanged-runtime run also passed; the temporary diagnostic print
was removed. No manufactured failing baseline is claimed.

Raw first-run, diagnostic, final-run and networking stdout are retained at
`../qualification-tank-close-steering-2026-10-10/`.

Current Core CI run 38019424372 continues to qualify its immutable c9777a7
checkout. It does not include the newly added test; that distinction must be
retained when inspecting its completed artifact. Runtime source remains the
same fingerprint e4c56526502dda4d61619177508c937cfc0c77369f02c4df9d07114348880ed2.

The Expert/Easy warning, remaining product scope, all-game qualification,
physical-device/controller/energy QA, production gates and exact-source native
release work are not completed. No main merge or Apple submission occurred.
