# Party Identity Contrast

Base: `ff0f9aaa6b2d5bb0c8dd91508fc28fbb3bc443c7`. Isolated branch: `fix/party-label-contrast-20261122`. No commit, push, merge, balance measurement, or physics change is part of this patch.

## Defect And Fix

The four-player identity captions previously used `Color(UIKit.TEXT, touch_opacity)` directly over the transparent world. Actual frozen viewport pixels from four ar/en landscape/portrait images measured only 1.2723-1.3380:1 across 16 captions. Their retained 4.5:1 assertion probe is RED (6 passed, 16 failed), without engine errors.

`TouchSource.party_identity_draw_data()` now supplies the exact layout/style consumed by `_draw_party_identity()`, called from normal drawing and the reaction early-return path. It uses opaque `UIKit.PANEL`, opaque `UIKit.text_color()`, and a neutral `UIKit.dim_color()` border through the existing `UIKit.stylebox` helper. P1-P4 and their existing unique symbols remain the identity; no invented character/slot colors are assigned.

The opaque identity is deliberately independent of touch opacity. Joysticks, button bodies, button labels, separator opacity, input rectangles, input routing, timers, party regions and scale remain unchanged. This is an informational canvas label, not a Button or a new hit target. Existing full-screen reaction input behavior is not changed.

Badge height is capped at 44 logical pixels, radius is 6, and font metrics/padding determine its width. If the cell cannot safely fit its text, or any actual `control_rects()` intersects the badge, the badge is omitted; input controls are never clamped, moved, or resized to make room.

Party mode currently ignores saved custom positions. Regression fixtures additionally feed real clamped custom single-source rectangles through the draw contract to verify collision omission, without adding custom-party positioning or changing the existing input policy.

## Verification

- Focused identity suite: **45750 passed**, 0 failed, both strict guards 0, no engine diagnostics; `green-identity-04` is authoritative.
- Numeric matrix: 1152 visible-party rows across light/dark, high contrast on/off, ar/en, landscape/portrait, left/right hands, humans 1-4, and opacity 0.05/0.15/0.5/1.0. Single-human identity stays absent. 0.15 is the settings UI minimum; 0.05 additionally exercises the renderer clamp boundary.
- Minimum text contrast: **14.7268:1**; minimum neutral-border contrast: **6.4382:1**. Opaque backing and ink remove dependence on arbitrary world pixels; black/white/world-brown/primary-color/matching-color composites are checked explicitly.
- Includes narrow cells, unsafe custom header targets, unchanged region/rect/scale/input assertions, and actual `_draw` helper-consumption probes for normal/reaction paths.
- Existing `party_touch_input`: **17155 passed**, 0 failed, strict guards 0, on final source (`affected-party-input-02`), including all 39 games/counts/orientations/handedness combinations.
- GPU after: four actual viewport images for humans=4, ar/en, 1280x720/540x960, using the unchanged `stage_zero_visual.tscn`, three additional play seconds. Native **Metal 4.0 / Forward+ / Apple M5**, both processes exit=0, strict guards=0, live guards passed, source hashes unchanged. All four images were inspected with `view_image` and show readable compact neutral-backed identities clear of the default input targets.
- Candidate simulation fingerprint: `be160db0e06c8cd3c77f8829f3ebbec96914aea9b458105b8d87e8d25bee5553`. This differs from frozen ff0f9aa as expected; it is not the fingerprint of a committed release.

Evidence lives outside Git under `qualification-quickplay-20261122/party-label-contrast-20261122/`; original before QA is under `melee-rendered-ff0f9aa/native-20261122-01/`. Preserve all attempts: `green-identity-01` had test-only inferred-Color parse errors; `green-identity-03` exposed an overly strict font-height limit and empty-data test abort. Neither is a valid GREEN result.

No full suite was run for this patch pending parent review. GPU images cover default light appearance; dark/high-contrast/low-opacity guarantees are numeric helper/compositing tests, not additional GPU screenshot claims. No iPhone, Duo, human multiplayer, accessibility certification, FPS, battery, thermal, Store-assets or upload claim is made. Other visually observed HUD percentage clipping remains outside this patch; button-text clipping was not assumed or changed.

## Dynamic Stick Follow-Up

The static rectangles alone missed a held joystick rebased near the identity. A new regression used actual `_handle_press`/`_handle_drag`/release paths for movement and aim, memory/ATV radius/handedness variants, 2-4 humans and both orientations. It reproduced 120 overlap failures without engine diagnostics. The helper now additionally checks the drawn active origin circle and the protruding clamped knob, including their strokes. No touch ownership, origin, knob, movement vector, static target, region, timer, or handler is modified.

`green-dynamic-01`: **46591 passed**, strict guards=0. `affected-input-dynamic-01`: **17155 passed**, strict guards=0. Current simulation fingerprint: `ba5ed309811ec89bd26c17a26a27ba0f20a3e0e06be9d74037a105dd4ed2bda5`.

The earlier four GPU screenshots and `qualification.json` belong to the preceding `be160db0...` source, not this update. No new native process was started for the dynamic follow-up; its GPU recheck remains pending coordination after releasing the native window to Ohm. Current evidence is separate in `qualification-dynamic-01.json`; do not promote old rendered evidence to the new source.
