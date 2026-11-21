# Siege Health HUD Fit

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-siege-health-hud-fit.
Runtime/test source: 1ca4158ba9c0a27464e0ef2b28eb40a0a148600b.
Parent: 05d21d37c9afa6c010d7b661a90adf35bd81f0f8.

## Confirmed Defect and Fix

The landscape siege HUD placed score and health on one clipped line next
to the character portrait. Actual rendering on the parent showed missing
percentage suffixes. base_siege now supplies score and health on separate
lines, using the existing shared HUD secondary status region. Health,
scoring, damage, AI and network schemas are not modified by this change.

The new actual-match test covers Arabic/English, one/four touch humans,
portrait 540x960 and landscape 1280x720, text scale 1.4, score 100, and
health 100/99/1 percent. It checks primary width, complete value retention,
secondary width/height, clipping policy and chip containment.

## Focused and Rendered Evidence

- Initial sandbox invocation failed before the suite: Godot could not open
  its user log and crashed (exit 134). This is not a test failure proving
  the HUD defect. Log: /tmp/kras-siege-hud-red.log.
- Local pre-fix suite failed (exit 1), including 192 primary-width failures
  and 192 secondary presentation-contract failures. Log:
  /tmp/kras-siege-hud-red-local.log.
- Corrected local headless suite: 673 assertions passed, exit 0.
  Log: /tmp/kras-siege-hud-green.log.
- Real Compatibility-renderer suite: 697 assertions passed, 24 actual
  captures, exit 0. Log: /tmp/kras-siege-hud-render.log.
  Images: /tmp/kras-siege-hud-render/siege-hud-screenshots/.
- Arabic four-human portrait/landscape and English one-human landscape/
  four-human portrait full-health images were manually inspected: score
  and health are complete. English landscape names are still clipped in
  the enlarged-text fixture; the early portrait capture also contains a
  transient start banner over the objective. These are separate UI QA
  limits, not silently counted as full interface qualification.
- Actual ten-second Arabic gameplay rendering: two nonblank captures,
  zero automated failures, exit 0. Both images manually inspected: health
  100/65/87 percent and scores are visible in each orientation.
  Images: /tmp/kras-siege-hud-gameplay/screenshots/.
  Log: /tmp/kras-siege-hud-gameplay.log.
- Focused log guards passed. The existing Compatibility screen-space-AA
  warning remains; it is not a new shader failure. git diff --check passed.

## Full Gate

The full gate on the exact runtime/test source above exited 0:

- 405 scripts compile. Inventory: 498 resources, 22 autoloads, 27 routes,
  eight characters, zero issues.
- 373862 assertions passed in 396.0 seconds.
- Separate real three-lap race and six boss regression probes passed.
- Stability: 39 matches, zero failures. Material, mesh, texture and audio
  PCM caches drained to zero. Settled memory: 141688588 bytes after five
  seconds. One cycle is not proof against long-term leaks or phone heating.
- Strict log guards passed. Harness no-assertion probes, router/save fault
  injection and the OS memory warning are intentional negative fixtures,
  not actual runtime successes or concealed failures.
- Server: 204 passed, zero failures/cancellations/skips, 921.165292 ms,
  using all six fresh current-run Godot world captures after verifying
  their presence. Log: /tmp/kras-siege-hud-server.log.

No runtime/test edits occurred during qualification. The rendering smoke
overlapped part of the gate, so elapsed times are not benchmark evidence.
Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.VzwUxc
Log: /tmp/kras-siege-hud-full.log.

## Remaining Release Gates

No main merge, Railway deployment, physical-device installation, signed
Xcode 27 Archive, upload, processing or App Review submission in this fix.
Natural balance reports have their own source fingerprints; parent reports
are not relabelled as current. All-game balance, fair-AI review, actual
iPhone/iPad multiplayer and sustained thermal/battery/frame-time tests,
production migration/backup and Internet acceptance remain outstanding.
The latest Chrome ASC check still redirected /apps to login with
authResult=FAILED despite the user's login report. No P12 import, password
request, new certificate or revocation.

Draft PR: https://github.com/shary17454/kras-pass/pull/160, based on the
siege observation branch. Task attachment failed at the existing 100-item
identity cap; unrelated attachments were preserved.
