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

## Four-Touch Follow-Up

A separate real-renderer run used English, four human touch slots and no
bots for `tank_arena`, `goal_guard`, `ring_rumble`, `sabaq_sawarikh` and
`crate_relay`. Both orientations and two additional play seconds were
captured: ten passes, zero failures, exit 0, strict Godot log check passed.
The portrait contact sheet was inspected: vehicle personal views and four
control regions rendered. This checks configured human slots, not four
physical people operating a device, simultaneous touch correctness or
controller support. No source changes were required.

Raw evidence: `/tmp/kras-b61e4b4-four-touch-en/visual-report.json`,
its `screenshots/` directory, `/tmp/kras-b61e4b4-four-touch-en.stdout`,
and `/tmp/kras-b61e4b4-four-touch-en-portrait.jpg`.

## Partial Balance Observation

Downloaded artifacts from run `37915371500` covered `tank_arena`,
`ring_rumble`, `crumble_court`, `bumper_bowl`, `fawda`, and `goal_guard`.
The existing `tools/balance-report.mjs` verifier passed with `--partial`,
`--paired`, seed offset 6800000, expected source commit b61e4b4 and
fingerprint `c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`.
All downloaded simulation start/end fingerprints match this source.

252 natural matches completed: 24 baseline, 16 paired difficulty, and two
stress matches per game. The six reports have no flags in this sample.
The verifier deliberately returns `complete: false`, 33 missing games,
`balanceReviewComplete: false`, and `releaseReady: false`. A small sample
with no flags is not proof of equal character or spawn win rates.
`crumble_court` slot wins were [2, 3, 10, 9], for example; extended
samples remain appropriate before balance acceptance.

Downloaded artifacts: `/tmp/kras-b61-balance-37915371500-observation/`.
No remote campaign was cancelled, restarted or promoted to a release gate.
