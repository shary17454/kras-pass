# Neutral input on gamepad loss - 2026-10-09

## Reproduced defect

The gamepad connection callback marked the player's frame disconnected and notified the match without clearing its held input. The polling fallback cleared movement and buttons but retained aim. Consumers of the loss notification could therefore observe stale movement, firing or turret direction.

The new regression test reproduces five failed assertions before the fix, including the frame observed inside the loss listener. The original red logs are retained.

## Fix

`src/input/input_router.gd` now calls the existing `InputFrame.clear()` in both loss paths before notifying the match. Player slot, device binding and disconnected status remain available to existing pause/reconnect logic. This does not remap devices, introduce AI takeover or change match rules.

`tests/suites/test_input_sources.gd` adds 17 assertions for immediate neutralization, loss-listener observations, polling fallback, single polling notification, retained device assignment and an unaffected second player.

## Verification

- Targeted input suite: 455 assertions pass, exit 0.
- Complete regression: 406181 assertions pass in 252.0 seconds, exit 0.
- Compilation: all 444 scripts compile, exit 0.
- Stdout and engine logs for each green run pass the repository runtime checker.
- Runtime fingerprint sampled during the full regression and again after regression/compilation: `54adea3029e2a4a5828d7b39023c874d1eb14eb21967e2acc9bc538404dc4f5d`.
- No source changes were made while those qualifying runs were active.

The complete run deliberately tests failed saves and empty-suite detection. Their injected diagnostics are retained, not classified as unexpected product failures. The macOS CA-certificate engine diagnostic remains; runtime checker success does not mean logs contain no errors or establish TLS qualification.

This test uses a synthetic absent device ID, not a physical Xbox/PlayStation/MFi controller. Physical reconnect, rumble and device mapping acceptance remain open. Existing match integration and race-condition fixtures continue to pass, but do not replace hardware QA.

## Source and release status

The fix is based on `fc426b5` on `feature/kras-online-random-rotation`. No main promotion or production change is performed.

The existing Distribution archive and IPA from `452f92f84e30f7b26bfebc92b2598f124316a56f` do **not** include this runtime fix. A new committed-source archive is required before uploading. Balance run `37961516661` and network run `37950626662` also retain their older captured sources; do not relabel them as qualification of this fix or cancel them merely because new code exists.

## Evidence

Raw red, targeted green, full regression and compilation stdout/engine logs are preserved in `../qualification-gamepad-loss-2026-10-09/`.
