# Round Announcement Layout

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-round-announcement-layout.
Runtime/test source: f680fa21109a364c1ec8579b2a10458d8c6afdcf.
Parent: 635081d985a94b4b4395dc4c7aa88eae66fc59f2.

## Defect and Fix

Actual preceding HUD captures exposed cropped intro titles in portrait.
Announcements previously used a full-viewport label, fixed base size 120,
no wrapping and a 1.5 pop scale for titles as well as countdown numbers.
Each replacement also left the previous fade tween running.

The shared announcement now wraps full localized text in the space between
occupied player HUD and touch controls, respecting viewport safe insets.
Titles use a fixed base size 36; countdown numbers use 64. Both retain the
user's text scale, including the supported maximum 1.6. The pop scale is
1.08 with reserved margins. Replacement kills the predecessor tween.
Layout is refreshed on viewport/card resize and the existing HUD tick.
The two countdown call sites explicitly select numeric presentation;
other announcement callers retain their existing API behavior.
No simulation, scoring, AI, save schema, network payload or asset changes.

## Focused Evidence

- Initial pre-fix test: 2873 passed, 1496 failed, exit 1, 18.4 seconds.
  /tmp/kras-announcement-red.log. This initial iteration used the 35-game
  rotation catalogue, not all 39 definitions; it is not 39-game evidence.
- Expanded catalogue/geometry check with initial countdown size 80:
  6193 passed, two failed, exit 1, 21.6 seconds.
  /tmp/kras-announcement-green.log is a failed run despite its filename.
  Diagnostic rerun: /tmp/kras-announcement-probe.log, same two failures.
  The English four-human landscape tank countdown extended into controls.
- Final size 64 plus two-digit countdown coverage: 6339 assertions passed,
  exit 0, 21.1 seconds. /tmp/kras-announcement-final.log.
- Actual Compatibility rendering: 7091 assertions passed, 64.0 seconds.
  /tmp/kras-announcement-render.log. Strict runtime-log guard passed.
  48 title/start/countdown captures are retained at
  /tmp/kras-announcement-render/round-announcement-screenshots/.
- Manual image inspection: Arabic four-human portrait siege title,
  English four-human landscape tank countdown, English one-human landscape
  siege title and Arabic one-human portrait tank start prompt. Full text
  remains visible and clear of the HUD and controls in those samples.

The test runs actual match scenes for siege/tanks, Arabic/English,
one/four touch humans, portrait 540x960 and landscape 1280x720, text scale
1.6. All 39 localized names plus start/finish/sudden-death and one/two-digit
countdowns are presented. It checks full text, visible lines, required
height, wrapping, initial/animated bounds and replacement tween disposal.
This is not actual play/render qualification of all 39 game scenes.
Compatibility AA/texture conversion warnings remain documented rather
than describing the renderer as warning-free.

## Exact-Source Gate

Full gate completed with exit 0 on the runtime/test commit above:

- 407 scripts compile; 500 resources, 22 autoloads, 27 routes, eight
  characters and zero inventory issues.
- 384024 assertions passed in 288.1 seconds.
- Separate three-lap race and six boss probes passed.
- Stability: 39 matches, zero failures; material/mesh/texture/audio PCM
  caches drained to zero, settled memory 139746181 bytes after five seconds.
  This one-cycle check is not sustained device or memory-leak qualification.
- Strict log guards passed. Intentional fault-injection warnings and the
  macOS system-certificate sandbox diagnostic remain visible in logs.

Log: /tmp/kras-announcement-full.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.gAKuDR.
No runtime/test edits during the gate.

Server tests used all six fresh current-run Godot captures, verified
present before execution. The sandbox run passed 203 and failed one
WebSocket test because listen on 127.0.0.1 was denied (EPERM), exit 1.
That failed log is retained: /tmp/kras-announcement-server.log.
The authorized local rerun passed all 204 tests, zero failures,
cancellations or skips, exit 0, 869.129125 ms:
/tmp/kras-announcement-server-local.log. This local result does not prove
production Railway rollout or Internet connectivity.

## Remaining Product Gates

The rendered English siege health percentage wraps undesirably at text
scale 1.6 in the one-human landscape sample. Existing health qualification
was at 1.4; this fix does not qualify all HUD fields at maximum text scale.
Current-source natural balance across all games, remaining fair-AI review,
physical iPhone/iPad multiplayer/gamepad/orientation and sustained frame
time, thermal/battery tests remain required. GitHub natural campaign
37549144464 is running against older source
3c4bbdb6d7437803cd53bba3e721b872ebb4675f, not this commit.

No main merge, Railway production deployment, database change or Apple
Archive/upload/processing/review submission. Live Chrome inspection and
navigation to the apps page still redirected to login with authResult=FAILED.
This report does not treat focused success as completion of the requested
full product or authorization to bypass release gates.
