# World Camera Boundary Qualification

## Source and observed fault

Base: `132f83df3e01af570c53f1ded40b4e5823075d3d`.
Implementation: `bfa75ea`.

The WORLD camera returned the selected driver's position directly, bypassing
the live-target filter and arena boundary protection. A still-alive falling
driver could therefore drag the view below or outside the world. Spectator
and empty-target fallbacks had the same missing boundary guard.

The integration camera assertion also used radial distance for square tank
maps. This incorrectly rejects valid square corners. The correction measures
overflow on both authored square axes; it does not reduce the playable world.
Other camera modes retain their existing integration assertion.

## Change

- Follow the selected driver only when eligible among the live targets.
- Prefer an in-bounds survivor when the driver is falling.
- Bound every WORLD fallback, including an empty target list.
- Preserve the complete square, including corners beyond its inscribed circle.
- Keep shared, race, chase and court camera paths unchanged.

## Focused evidence

Godot 4.7.1, headless, explicit temporary save directories:

- Original camera: 2 assertions passed, 5 failed; process exit 1.
  `/tmp/kras-camera-boundary-baseline.log`.
- Corrected camera: all 7 assertions passed; process exit 0.
  `/tmp/kras-camera-boundary-fixed.log`.
- Compilation: all 325 scripts compiled; process exit 0.
  `/tmp/kras-camera-boundary-compile.log`.
- Repository log guards for the corrected suite and compile log passed.
- `git diff --check` passed before commit.

The fixture uses a translated arena and checks a valid corner, a falling local
subject, a surviving subject, all-subjects-falling, spectator fallback, and an
invalid previously retained focus. This is not physical-device visual QA.

## Other current qualification handles

Main source `132f83d` is independently being qualified by:

- Game Quality run `37148706983`.
- Natural Balance Campaign run `37148818784`, seed offset `100000`.

These runs do not qualify this later camera commit. They must not be reported
as completed or successful until their terminal results are inspected.

Railway deployment `f40b84c3-54da-4dcc-b884-9e64ef45307d` reported SUCCESS
for main `132f83d`; production `/health` returned `ok: true`,
`authentication_ready: true`, `multiplayer_enabled: false`. The last 40 log
lines showed normal startup and the Config-as-Code deprecation warning, not
proof of complete database/auth/online qualification.

The previous source `20a1001` natural zone_hold artifact from run `37146577863`
completed 24 baseline and 16 mirrored difficulty matches plus two smoke cases.
Its slot bias was 0.07, flags empty, versus the older independent campaign's
0.29167 slot bias. This small sample is evidence of improvement, not proof that
every game or all character balance issues are resolved. Its source is not the
later tied-target or camera change.

## Release gates still open

Full clean-checkout CI, all-game natural balance, network qualification,
physical portrait/landscape and controller QA, frame pacing/battery/thermal
measurement, production online readiness, current device profile refresh,
fresh source-bound signed Archive, App Store build selection/processing and
submission remain independent requirements. Apple Developer still displays
the user sign-in page. No P12 import or certificate change was performed.
This change is not an App Store upload or review submission.
