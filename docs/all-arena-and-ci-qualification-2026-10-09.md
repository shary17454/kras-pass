# All-Arena Visual Coverage And Completed CI Evidence

## Current Runtime

Working base: `d9841d2543f216bb1d989fd1dd7525e903c36d95`, branch `feature/kras-online-random-rotation`.
Runtime source matches `bc46d4e00bc842ad4aff17a8c17c198ea9370641`; the intervening commit changes only the archive report.
Runtime fingerprint before rendering and after compilation: `54adea3029e2a4a5828d7b39023c874d1eb14eb21967e2acc9bc538404dc4f5d`.
Only visual QA scripts/tests and this report change in this phase. No production runtime, signing or release-number edits.

## Visual Harness And Coverage

`tests/stage_zero_visual.gd` adds `--all-arenas` and an optional `--arenas=` filter. Default capture scope and default filenames remain unchanged. Expanded filenames include arena IDs to avoid overwriting variants. Reports compare the actual instantiated arena with the requested arena. Empty or unknown selections cannot silently produce a successful empty run.
`tests/suites/test_visual_roster_policy.gd` verifies unique complete pairing coverage, original default order, game filtering and exact arena filtering: 182 assertions pass. All 444 scripts compile.

Catalogue-derived matrix: 39 games, 57 declared game/arena pairings, 34 distinct arenas. Both Arabic and English full runs capture each pairing once in portrait (540x960) and landscape (1280x720), four human touch slots, two additional play seconds, Metal renderer. Independent JSON/PNG audit confirms 228 full captures, unique complete coverage, actual/requested arena equality, nonblank pixels, bounded controls, four distinct touch slots and nonempty PNG files.

The full runs are **not clean passing campaigns**:

- Arabic: 114 captures, one failure at `bumper_bowl/bumper_bowl/portrait`; paused=true and pause menu present immediately after an application-background event.
- English: 114 captures, two failures at `zone_hold/dune_ring/portrait` and `sabaq_sawarikh/magma_ring/portrait`, with the same background/pause condition.
- Separate, explicitly filtered rechecks retain the same roster/play time and cover both orientations: Arabic 2/2 pass; English 4/4 pass. Every originally failed pairing/orientation is present in those rechecks. Original failures and images remain preserved; no clean full-run result is fabricated.

The first sandboxed renderer launch never initialized Godot or created its engine log, reporting macOS UI-service connection errors. A process sample showed it waiting in the AppKit event loop. That owned launch was intentionally stopped (exit 143), its diagnostics retained, and local system-permission rendering initialized Metal successfully. This was not a restart merely because an observation timed out.

## Open Visual Finding

Manual inspection of `tank_arena/tank_oasis`, four human slots, both orientations, shows foreground rock cover partially obscuring P2's vehicle in its own follow view. Its head/marker remain visible; automatic nonblank/control checks do not detect this body occlusion. This needs camera/cover visibility investigation and is not accepted as complete player readability.

Reproduction: use `--all-arenas --games=tank_arena --arenas=tank_oasis --locale=ar --humans=4 --play-seconds=2` with the visual scene and a new isolated test directory. Original oasis PNGs remain in the full Arabic evidence.

Only three screenshots were manually inspected in this pass (oasis landscape/portrait and the English magma portrait recheck). This is not a human review of every image, full-track gameplay, real four-person touch testing, device/controller/FPS/thermal/battery acceptance or all games READY.

## Current Core CI

Run `37967296347`: SUCCESS, exact source `bc46d4e00bc842ad4aff17a8c17c198ea9370641`, matching tree and intended head, no tracked changes. Independent review checks all 23 retained runtime/import logs.

- 406181 full regression assertions pass; 444 scripts compile.
- 117 shortened stability matches pass, zero reported failures.
- Inventory issues: none.
- Default server suite: 269 pass, six capture-dependent skips, zero failures. Capture-enabled suite: 275 pass, zero skips/failures.
- Four real engine peers complete a mixed three-round tournament plus three tie-break rounds. Histories, scores, tournament state and champion match across peers; host and guest reconnect. Points `[5,9,10,10]`, champion `[3]`.

This remote Core run predates the new visual-harness test additions. Their focused local suite and compilation above are separate evidence, not a relabeled remote full regression. Existing deliberate negative save/harness diagnostics are retained by the runtime log policy.

## Completed Older-Source Network CI

Run `37950626662`: SUCCESS, all 40 Core/per-game jobs. Forty unique source attestations match `b5e4f9e7d61c3dedbb6e79b6741ebf86f57a9c69`, intended head/run and empty tracked changes. All 1235 retained import/runtime logs pass the repository checker.
Independent peer comparison covers 176 cases, 538 peer results and 394 authoritative round histories across all 39 games. Mandatory ordinary/tournament cases each total 78; 20 additional regression/final cases account for the larger count. Scores, arena histories, round histories, match counts and tournament state agree across peers.
This source predates both the save-backup and gamepad-loss fixes. It is not current-source or Railway-production networking acceptance.

## Completed Older-Source Balance CI

Run `37961516661`: SUCCESS, 41 jobs, source `452f92f84e30f7b26bfebc92b2598f124316a56f`, seed offset 9200000, runtime fingerprint `274d1649bf08d310aab79374014795d542e687e47d2680975398598187ad1774`.
Independent paired/source/seed validation: 39/39 games, 1638 natural matches, no missing evidence or review flags in this cohort. All 117 raw import/runtime/stdout logs pass. `balanceReviewComplete=false`, `releaseReady=false`; prior cohorts' flags remain relevant and are not erased by this sample.
Boss baseline defeats/survivals: Colossus 15/9, Dreadnought 24/0, Forge 24/0, Sovereign 23/1; no unknown outcomes. All four difficulty comparisons record 16 defeats. Stress outcomes are preserved, not inferred from score.
This source predates gamepad-loss handling; do not label its fingerprint as current.

## Next Captured CI Handles And Release Gates

- New all-game network run `37970339411`, captured source `d9841d2543f216bb1d989fd1dd7525e903c36d95`.
- New balance run `37971414154`, captured same source, independent seed offset 10100000.
- Both use current runtime fingerprint 54adea...; they remain incomplete and were launched only after previous campaigns reached SUCCESS. No campaign was cancelled for observation delay.

No main merge, production deployment, migrations, Apple upload or review submission. Product-scope completion, visual readability, manual/device acceptance, production backup/restore authorization and actual production connectivity remain open. Stage-zero acceptance is not waived.

## Preserved Evidence

- `../qualification-visual-all-bc46d4e-2026-10-09/`: all full/recheck reports, 234 PNGs, unit/compile logs and blocked-launch diagnostics.
- `../qualification-core-bc46d4e-2026-10-09/`: full current Core artifacts.
- `../qualification-network-b5e4f9e-complete-2026-10-09/`: complete older network artifacts.
- `../qualification-balance-452f92f-complete-2026-10-09/`: all balance artifacts and independently verified summary.
