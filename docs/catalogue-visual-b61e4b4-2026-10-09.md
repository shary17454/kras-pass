# Catalogue Rendering Qualification

Source: `b61e4b44894e12ad05f14981d3a1686efa2e058b`,
`feature/kras-online-random-rotation`, `shary17454/kras-pass`.
No gameplay source was changed for these checks.

## Scope

Godot 4.7.1, Metal Forward+, Apple M5. `tests/stage_zero_visual.tscn`
rendered all 39 catalogue games, one default arena per game, Arabic,
one human touch slot plus three bots, landscape 1280x720 and portrait
540x960, with two additional seconds of play after the legal lifecycle
transitions. These are desktop smoke captures, not physical human play.

## Results

The initial process exited 1: 78 captures, 77 passes, one failure.
`boss_forge/portrait` had four live players, valid control bounds and
nonblank pixels, but was paused with the pause menu present. The log
records `app backgrounded` immediately before this capture.

A separate targeted rerun of `boss_forge`, using a new isolated save
directory and the same settings, exited 0: both orientations passed,
unpaused, with no pause menu. The original failure is retained; the
full initial run is not represented as an uninterrupted success.
Both logs passed `tools/check_godot_log.sh` independently.

Landscape and portrait contact sheets were inspected. All catalogue
entries rendered scenery, HUD and controls. The portrait boss rerun
was also inspected at full size. Pixel diversity and control bounds
do not establish readability, camera quality, balance or visual polish.
Small shared arenas and character visibility still need focused QA.

## Raw Evidence

- `/tmp/kras-b61e4b4-visual-ar-one.stdout`
- `/tmp/kras-b61e4b4-visual-ar-one-save/visual-report.json`
- `/tmp/kras-b61e4b4-visual-ar-one-save/screenshots/`
- `/tmp/kras-b61e4b4-visual-landscape-progress.jpg`
- `/tmp/kras-b61e4b4-visual-portrait.jpg`
- `/tmp/kras-b61e4b4-visual-boss-recheck.stdout`
- `/tmp/kras-b61e4b4-visual-boss-recheck/visual-report.json`
- `/tmp/kras-b61e4b4-visual-boss-recheck/screenshots/`

The reports, logs, screenshots and contact sheets were also preserved in
`../qualification-catalogue-visual-b61e4b4-2026-10-09/` outside the checkout.

## Remaining Gates

This does not qualify every arena, English, all local player counts,
gamepads, sustained gameplay, phone thermals, battery or frame time.
No game is promoted to READY from these screenshots. Current-source
network run `37915365019` and balance run `37915371500` were still
live at this observation. No main merge, Railway deployment, native
archive, upload or App Review submission was performed here.
