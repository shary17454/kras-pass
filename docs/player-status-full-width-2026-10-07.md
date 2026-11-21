# Player Status at Maximum Text Scale

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-player-status-full-width.
Runtime/test source: 3eba1b106fa93aae0887b0b6b68435a57c46e466.
Parent: 87b30b847be1de6fd0fae7b66cbe8b7a0940946b.

## Defect and Fix

Actual preceding announcement captures exposed a split siege health
percentage at the supported maximum text scale 1.6. The previous health
regression covered 1.4, not that maximum. Its status label shared the
portrait/value column, leaving insufficient width in landscape.

Secondary status is now a full-card-width row beneath the portrait/value
row. Landscape card minimum width also scales with the selected text
scale, keeping numeric armor readable in compact multiplayer cards.
Portrait continues using its existing adaptive grid. Fonts and saved
text-scale preferences are not reduced or overwritten. Existing controller
values, portraits, player symbols, localized labels and meters are retained.
There are no gameplay, AI, network schema, scoring or save changes.

## Focused Evidence

- Initial test-edit attempt had mixed indentation and did not load:
  /tmp/kras-status-red.log, exit 1. It is not proof of the HUD defect.
- Corrected pre-fix siege test: 737 passed, 32 failed, exit 1.
  /tmp/kras-status-red-local.log. Failures demonstrate the split percentage
  and insufficient status width at 1.6.
- Full-width status first iteration: 769 assertions passed, 2.8 seconds.
  /tmp/kras-status-green.log. This precedes the landscape-width change.
- Tank regression at 1.6 then exposed insufficient numeric width:
  1457 passed, 112 failed. /tmp/kras-status-tank.log. This failure was not
  converted into a pass by weakening the font/region comparison.
- Final landscape-width change: 1569 tank assertions passed, 6.8 seconds.
  /tmp/kras-status-tank-final.log.
- Final Compatibility rendering: tank 1625 assertions, 56 captures,
  111.3 seconds; siege 793 assertions, 24 captures, 12.6 seconds. Logs:
  /tmp/kras-status-tank-render.log and
  /tmp/kras-status-siege-final-render.log. Both process exits and strict
  runtime-log guards passed.
- Tank images: /tmp/kras-status-tank-render/hud-value-screenshots/.
  Siege images: /tmp/kras-status-siege-final-render/siege-hud-screenshots/.
  Arabic four-human portrait tank, English four-human landscape Standard,
  English one-human landscape Homing, English one-human landscape siege
  at 100 health and Arabic four-human portrait siege were manually viewed.
  Full numeric values/status are readable in these samples.
  One earlier Arabic one-human tank capture contains the automatic pause
  overlay; that frame is not an unobscured HUD visual acceptance image.
  An earlier siege render before the width change is retained separately:
  /tmp/kras-status-siege-render.log, not final-source qualification.

These regressions use actual MatchScene HUDs, Arabic/English, one/four
touch humans, both orientations, all seven tank shell types and siege
health 100/99/1. They preserve exact controller text and test numeric
width, status height, containment and visible lines at text scale 1.6.
Siege percentages must remain on one line. They do not test all 39 actual
game scenes, all device resolutions or physical touch/controller behavior.
Compatibility AA/BPTC conversion warnings remain visible in logs.

## Dependency Audit

Current server lockfile: npm audit --omit=dev --json exited 0, audit
report version 2, zero reported vulnerabilities at every severity.
Evidence: /tmp/kras-status-dependency-audit.json.
No dependency, lockfile or production data changes. This advisory lookup
is not a complete application/security review or a guarantee of no risks.

## Full Gate

The first full run was interrupted, not accepted as a complete gate.
Its tests reported 384344 assertions passed in 241.8 seconds; race and
boss probes reported success, but stability ended without its completion
and cache-release summaries. After the interruption, the process handle
was absent and a system process check found no live checker/Godot process.
Retained log: /tmp/kras-status-full.log.
Retained evidence:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.9UK1vJ.

A fresh full run completed with process exit 0 on the unchanged
runtime/test source above:

- 407 scripts compile; 500 resources, 22 autoloads, 27 routes, eight
  characters and zero inventory issues.
- 384344 assertions passed in 296.6 seconds.
- Separate three-lap race and all six boss probes passed.
- Stability completed 39 matches with zero failures. Material/mesh/texture
  and audio PCM caches drained to zero; settled memory after five seconds
  was 139746253 bytes. This single-cycle probe is not proof of no long-term
  leaks or physical-device frame-time/battery/thermal qualification.
- Strict log guards passed, retaining intentional fault-injection warnings
  and the macOS system-certificate sandbox diagnostic in the evidence.

Log: /tmp/kras-status-final-full.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.CkHzei.
No runtime/test edits during the gate. Server tests used all six fresh
current-run world captures after verifying their presence: 204 passed,
zero failures/cancellations/skips, exit 0, 1139.989041 ms.
Server log: /tmp/kras-status-server-final.log. Local WebSocket success is
not proof of production Railway rollout or Internet connectivity.

## Release Limits

Portrait tank objective/hint placement at maximum text scale still needs
separate visual work: the four-human Arabic capture wraps near the first
touch-region heading. This status fix does not qualify all overlays.
Current-source all-game natural balance, remaining fair-AI review,
physical iPhone/iPad multiplayer/gamepad/orientation checks, sustained
frame-time/thermal/battery measurements and production Railway rollout
remain outstanding. This is not a full-product acceptance report.
No main merge, production database export/change, new certificate or P12
import, signed local Xcode 27 Archive, Apple upload, processing or review
submission. The last Chrome ASC check redirected to login despite the
reported sign-in; credentials were not requested or displayed.
