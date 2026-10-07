# HUD Value Text Fit

Base: `4d52f7a13e69a694eddbb19a7d179e148072ec13` (PR 149).
Branch: `fix/kras-hud-value-text-fit`. No main merge or Apple upload.

## Change

The prior enlarged English portrait capture clipped `Standard` in the
player value chip. MatchHUD now separates a multiline controller value at
its first newline: the numeric primary stays prominent and LTR, while the
localized secondary status uses a smaller wrapping Label inside the chip.
The complete controller string is preserved. Single-line values retain the
existing primary presentation and hide the secondary region.

This is shared HUD presentation, not a special-case abbreviation of tank
weapons. No damage, ammunition, AI, scoring, camera, input or networking
rules changed. Long secondary statuses may increase card height, rather
than silently clipping. Radar clearance regression still passes.

## Current Evidence

- Ammunition status headless suite: 1345 assertions passed.
- Actual rendered ammunition suite: 1401 assertions passed, 56 PNG captures.
- Numeric direction suite: 11 assertions passed.
- Live status-toast suite: 3321 assertions passed.
- Tank radar clearance suite: 89 assertions passed.
- Compilation: all 398 scripts compile.
- Strict completed-run log guards and `git diff --check` passed.

The new suite exercises all seven ammunition names with 140% text size,
Arabic/English, one/four touch-configured humans and portrait 540x960 /
landscape 1280x720. It checks primary text width, lossless string
reconstruction, unclipped wrapping, required height and containment inside
the card. Scene cleanup and restoration of settings/locale/window are part
of the completed test run.

Logs: `/tmp/kras-hud-value-qualified.log`,
`/tmp/kras-hud-value-rendered.log`, `/tmp/kras-hud-numeric-qualified.log`,
`/tmp/kras-hud-status-qualified.log`, `/tmp/kras-hud-radar-qualified.log`,
`/tmp/kras-hud-compile-qualified.log`.
Captures: `/tmp/kras-hud-value-rendered-save/hud-value-screenshots`.
Manually inspected Arabic one-human portrait Ricochet, English one-human
portrait Ricochet and English four-human landscape Ricochet. The landscape
status wraps its ammo count onto another line while remaining inside the
card. Other saved images are automated capture evidence, not individually
claimed manual inspections.

Earlier development runs aborted because of test-fixture indentation,
an invalid Fighter property and teardown inside the orientation loop.
Their apparent partial success summaries are NOT passing evidence; the
strict guard rejects script errors. All listed final runs completed after
those harness fixes. No valid complete pre-fix red-suite count is claimed.

Rendering: local Godot 4.7.1 official, Metal 4.0 Forward+, Apple M5.
This is not physical iPhone/iPad performance, battery or thermal testing.
The subsequent full regression on commit `3c4bbdb` is recorded in
`hud-full-regression-2026-10-07.md`; older balance/release reports are not
promoted to current proof.

## Release Gates

App Store Connect showed the account name but navigating/reloading the
apps list failed with `ERR_FAILED` during the current session. There is no
current verified build inventory, upload, processing or review submission.

All-game balance/polish/perception, physical-device QA, approved source
promotion, production backup/protocol/deployment/auth acceptance, frozen
Version/Build, local Xcode 27 Distribution Archive, signing verification,
upload, processing and separate App Review submission remain incomplete.
No READY classification, certificate change/import or Xcode Cloud use.
