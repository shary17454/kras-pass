# Native Pause Controller Follow-Up

Parent: `b26d8b7c216e8f73f3a8d5eee7e126c095dff103`.
Branch: `feature/kras-online-random-rotation`.

## Actual Input Failures And Fixes

Testing actual InputEventJoypadButton events found that the configured B
button is `ui_back`, not `ui_cancel`, and A did not produce `ui_accept` in
this project. The native menu now accepts the existing back action and the
standard A button explicitly. Direction and activation callbacks remain scoped
to the current presentation generation. Unknown or obsolete callbacks are
still ignored.

Cancellation is delivered to UIKit rather than immediately tearing down the
Godot pause state: a restart-confirmation dialog can be cancelled without
leaving its parent menu. Controller navigation selects cancel/restart in that
dialog and dismisses it before delivering an accepted restart. Online restart
remains disabled. Native focus navigation scrolls the selected button into
view. Reduced transparency changes update the open panel and buttons.

## Evidence

- Final presenter and actual controller-event integration: 67 assertions
  passed, exit 0; strict runtime log passed.
  `/tmp/kras-native-glass-controller-all-buttons-fixed.log`.
- Network regression suite: 400 assertions passed, exit 0; strict log passed.
  `/tmp/kras-glass-controller-network.stdout`.
- Lifecycle regression: 19 assertions passed, exit 0; strict log passed.
  `/tmp/kras-glass-controller-lifecycle.log`.
- All 427 scripts compile; strict compile log passed.
  `/tmp/kras-glass-controller-final-compile.log`.
- Current native sources built with local Xcode 27 for device arm64 and
  simulator arm64/x86_64.
  `/tmp/kras-native-glass-controller-build.stdout`.
- `git diff --check` passed.

The full 392405-assertion pass belongs to the parent native pause change,
before this follow-up. The focused affected regressions above qualify the
follow-up; they do not claim another full-suite pass or actual UIKit visual QA.
The first event test emitted a script error after indexing an empty command
array even though its harness printed success. That run is rejected. The
fixture now checks the array before accessing it, and the final run passes
strict log validation with the actual expected commands.

## Balance Provenance

The first expanded ring sample completed 96 baseline, 48 difficulty and two
smoke matches without balance flags, but its start/end source fingerprints
differ because the discovered input fixes were made during the run. It exited
1 and is diagnostic only, not accepted release evidence.
`/tmp/kras-ring-current-96-report/report.json` and
`/tmp/kras-ring-current-96.stdout` retain that rejected run.

A repeat on the frozen final simulation source passed, exit 0, with 96
baseline matches, 48 matched difficulty matches and two smoke matches in
151.1 seconds. All matches completed and no balance flags remained in this
sample. Baseline slot wins: [23, 31, 21, 21]; slot bias 0.0729167, character
bias 0.03125, expert edge 0.6133056. Both smoke modes completed successfully.
`/tmp/kras-ring-final-96-report/report.json`, seed offset 3200000; strict log
validation passed. Start, end and current simulation source fingerprints match:
`9a825ccaf12098370e8a3af3d8cf90f87d8a77da873fd9a7c6a7698e86498742`.
The checked-in evidence is under `docs/qa/native-controller-2026-10-08`.
This expanded independent sample does not reproduce the small parent
campaign's ring spawn warning. It is not a statistical guarantee, a sweep of
the other 38 games or a physical-device playability/performance acceptance.

## Still Not Qualified

Actual native dialog/VoiceOver/large-text visual QA and physical controller QA,
physical-device performance/thermal acceptance, remaining balance warnings,
production rollout, exact-source signed Archive, upload, processing and review
submission remain open. The Mac is locked; no App Store Connect or production
settings were changed. No P12 import, certificate creation/revocation or
physical-device installation was performed.
