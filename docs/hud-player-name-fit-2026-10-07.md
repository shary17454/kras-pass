# Complete Player Names in Match HUD

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-player-name-hud-wrap.
Runtime/test source: 0539fd9a1acdfb315a45daa22641611b5d67db88.
Initial heading commit: 660129a9b7b6a2eb4e762ed7015a5a60a5ac10df.
Parent: d7a8eb491b6e883624814aed0cc634d4e7da2175.

## Defect and Fix

The preceding rendered siege health check exposed clipped English player
names with large UI text. The shared player card put the name beside the
portrait and silently clipped it. Names now use smart word wrapping and a
full-width heading above the portrait/value row. The complete localized
name, player symbol, human "You" prefix and leader crown are preserved;
user text scale is not reduced to hide the issue. Character identities can
wrap up to three lines; the regression verifies all their lines are visible.
Custom multiplayer profile names use a single heading line with explicit
ellipsis if necessary, rather than expanding a match card indefinitely.
Their full text remains in the label and tooltip, with pass-through hover
events enabled. Profile/save data are not truncated or migrated by this fix.
Physical touch tooltip interaction is not verified here.

The first wrapping-only iteration passed geometry tests but rendered tall,
inefficient name columns. Those images and logs are retained; the final
full-card-width heading addresses that visual problem rather than calling
the initial passing checks sufficient. No scores, health, AI, gameplay,
network schemas or assets were changed.

## Focused and Rendered Evidence

- Actual scene pre-fix regression: 2445 passed, 628 failed, exit 1.
  Log: /tmp/kras-hud-name-red.log.
- Initial wrapping-only iteration: 3073 headless assertions and 3105
  rendered assertions passed. Its overly tall rendered columns were
  manually rejected. Logs: /tmp/kras-hud-name-green.log and
  /tmp/kras-hud-name-render.log.
- Final heading layout: 3073 assertions passed, exit 0, 22.3 seconds.
  Log: /tmp/kras-hud-name-final.log.
- Final Compatibility rendering: 3105 assertions passed, 32 actual
  captures, exit 0, 45.8 seconds. Log:
  /tmp/kras-hud-name-final-render.log.
  Images: /tmp/kras-hud-name-final-render/hud-name-screenshots/.
  English one-human landscape siege and Arabic four-human portrait siege
  images manually inspected: all identities and the leader crown readable.
- New coverage: eight original characters, Arabic/English, siege/tank
  cards, one/four touch humans, both orientations, text scale 1.4, each
  leader slot. Checks retain full name/symbol text, real wrapping when
  needed, required line height, card containment and score non-overlap.
  This sample covers original character names, not all custom profile names.
- Existing siege status regression: 673 assertions passed (4.5 seconds).
  Log: /tmp/kras-hud-name-siege-values.log.
- Existing tank ammunition/status regression: 1345 assertions passed
  (7.0 seconds). Log: /tmp/kras-hud-name-tank-values.log.
- Strict focused/render log guards and git diff --check passed. Desktop
  Compatibility warnings for unsupported screen-space AA and BPTC texture
  conversion to RGBA8 remain; no unsupported claim of warning-free rendering.

## Exact-Source Full Gate

The initial heading full gate stopped with 376886 passed, 48 failed in
360.1 seconds. All failures asserted the previous silent-clipping policy
for long custom names. This is retained as a failure, not relabelled a pass.
Log: /tmp/kras-hud-name-full.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.JfdhvG.

The updated custom-name test preserves viewport/score/effect/round/font
checks and adds bounded height, explicit overflow, full tooltip identity
and score non-overlap. A three-line custom-name attempt then failed 48
height checks (3465 passed). These geometry failures were retained:
/tmp/kras-hud-name-overflow.log and
/tmp/kras-hud-name-overflow-probe.log. Height now uses actual logical
viewport coordinates, matching the rectangles rather than window pixels.
Custom names now have the bounded single-line policy above.

Bounded custom-name headless run: 3513 passed; rendered run: 3525 passed,
12 captures, 28.1 seconds. Logs: /tmp/kras-hud-name-overflow-final.log and
/tmp/kras-hud-name-custom-render.log. Arabic tank portrait and English
tag landscape were manually inspected: explicit ellipses, cards leave
the arena visible. Images:
/tmp/kras-hud-name-custom-render/hud-custom-name-screenshots/.
Original-character regression with visible-line checks: 3585 passed,
13.3 seconds. Log: /tmp/kras-hud-name-bounded.log.
These focused runs precede the final hover-filter assertion; they do not
alone qualify that last change.

Final full gate on the exact runtime/test source above exited 0:

- 406 scripts compile; 499 resources, 22 autoloads, 27 routes, eight
  characters and zero inventory issues.
- 377686 assertions passed in 295.9 seconds, including the final tooltip
  hover-filter assertion and all original-character visible-line checks.
- Separate real three-lap race and six boss regression probes passed.
- Stability: 39 matches, zero failures. Material, mesh, texture and audio
  PCM caches drained to zero; settled memory: 141690592 bytes after five
  seconds. This one-cycle probe is not proof against long-term leaks or
  physical-device heating.
- Strict log guards passed. Intentional harness, router/save and memory
  warning fault-injection fixtures are not concealed runtime failures.
- Server: 204 passed, zero failures/cancellations/skips, 2153.436 ms. All
  six fresh current-run Godot world fixtures were verified present before
  the run. Log: /tmp/kras-hud-name-server.log.

Log: /tmp/kras-hud-name-bounded-full.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.y6C7vc.
No runtime/test edits during this gate; elapsed times are not a performance
improvement claim or physical frame-time measurement.

## Release Limits

This is scoped HUD QA, not acceptance of the full requested product.
Current-source all-game natural balance, remaining fair-AI review, physical
iPhone/iPad multiplayer/controller/orientation checks and sustained frame
time, thermal/battery tests remain required. Long intro headings in frozen
fixture captures and physical-device custom-name/tooltip interaction need
separate UI qualification.
No main merge, Railway deployment or production account/migration change.
No signed Xcode 27 Archive, upload, build processing or Apple review
submission. The ASC session was not refreshed by this coding fix; the last
live Chrome check redirected to login with authResult=FAILED.

Draft PR: https://github.com/shary17454/kras-pass/pull/161, based on the
siege health HUD branch. Task attachment failed at the existing 100-identity
cap; unrelated attachments were preserved.
