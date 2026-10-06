# Tank Radar and HUD Clearance

Base: `300a6f5fbb92cdca5828a9c05047e325e0cc6797` (PR 148).
Runtime: `0a0fb81dd1118609afb3ee8d8d4bbb9ac035baf9` on
`fix/kras-tank-radar-hud-clearance`. No main merge or release upload.

## Reproduction and Fix

The radar used portrait Y=450 independently of the objective's Y=460.
The new test reproduced 16 failures (73 assertions passed), including
objective intersections and enlarged-HUD collisions.

MatchHUD now reserves an auxiliary-overlay height and provides its top below
the actual HUD and live status-message stack. The radar is created after HUD
setup and reads that clearance. A layout signal updates it immediately when
HUD messages/layout change. Redraw remains throttled at the existing 10 Hz;
no per-frame layout polling was added. The left safe inset is respected.
The portrait objective follows the reserved overlay if more clearance is
needed. Neither the objective nor radar is suppressed.

No movement, damage, scoring, AI, network protocol or tournament rule changed.

## Checks

- New headless layout suite: 89 assertions passed.
- Actual rendered suite: 105 assertions passed, including 16 saved captures.
- Live status-toast HUD suite: 3321 assertions passed.
- App lifecycle/background-pause suite: 13 assertions passed.
- Compilation: all 397 scripts compile.
- Strict completed-run log guards and `git diff --check` passed.

The new suite covers Arabic/English, one/four touch-configured humans,
540x960/1280x720 orientations, 100%/140% text size, active status messages,
resize, viewport bounds and objective/HUD clearance. It does not force the
radar's layout method; the production layout signal is exercised. Each match
is torn down, and original locale, text scale and window dimensions restored.

Logs: `/tmp/kras-radar-layout-{red,final,rendered-final}.log`,
`/tmp/kras-radar-status.log`, `/tmp/kras-radar-lifecycle.log`,
`/tmp/kras-radar-compile.log`.
Final captures: `/tmp/kras-radar-layout-rendered-final-save/radar-screenshots`.
Selected enlarged portrait one-player English and four-player Arabic captures
were manually inspected after the temporary start announcement faded.

Rendering is desktop Godot 4.7.1 official, Metal Forward Mobile, Apple M5.
This is not iPhone/iPad FPS, thermal, battery or Internet acceptance. The
macOS CA diagnostic remains an environment diagnostic, not clean-import proof.
The earlier full-suite/all-game evidence is not a fresh full regression of
this changed runtime. No READY promotion is asserted.

## Remaining Visual Finding and Release Gates

The enlarged English one-player portrait capture clips `Standard` inside
the player value chip. This pre-existing text-fit issue is not hidden by a
green radar test and still requires a scoped fix and visual regression.

All-game balance/polish/perception, physical-device QA, approved source
promotion, production backup/protocol/deployment/auth acceptance, frozen
Version/Build, local Xcode 27 Distribution Archive, signing verification,
upload, processing and separate App Review submission remain incomplete.
No certificate import/change, Xcode Cloud build or Apple submission occurred.
