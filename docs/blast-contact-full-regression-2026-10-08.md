# Blast contact repair: complete local regression

Verified source `78d11abdb35144a6c754414487606093dd5c1435`, branch
`feature/kras-online-random-rotation`, official Godot 4.7.1 on macOS.
Source fingerprint before/after remains
`b90edfc4d8fb5f0b42fa8063f41e564f252a0c9f40ea09e2f3e2db1fa990d553`.
No tracked source changes occurred during the run. Godot-generated untracked
UID/import sidecars were preserved and were not added as release changes.

## Completed local gate

Ran `tests/test_runner.tscn`, fixed 60 physics FPS, with external isolated
test storage `/tmp/kras-contact-full-suite-save`. Exit zero, 186.6 seconds,
`ALL TESTS PASSED - 392596 assertions`. The strict tests log guard passed.
This is the complete suite, not only the 381-assertion Blast fixture.
The earlier compile gate covers 430 scripts; the natural Blast sample covers
42 matches and still reports its difficulty warning.

The raw log includes deliberately failing nested TestHarness probes and
failed-save fixtures. These are asserted negative test cases, not concealed
top-level failures. The final suite and strict log guard both passed.

Raw local evidence is retained outside Git at the workspace-relative path
`../qualification-blast-contact-full-2026-10-08/full-suite.log`.
SHA-256: `beab91770bb99dbd6f652905df5b7f0051605f50147d99022598d5cc1e66854a`.
Player save data and test-generated replays/session artifacts are not committed.

## New exact-source remote qualification

Confirmed all previously listed branch jobs were terminal before dispatch.
Both new runs resolve to the exact source SHA above:

- Game Quality `37812970245`, full matrix (`core_only=false`,
  `balance_campaign=false`): core plus per-game networking checks.
  Initial inspection verified running/queued jobs and successful checkout of
  the first active network job. No matrix completion is claimed.
- Natural Balance Campaign `37813002835`, independent offset 4200000:
  verified accepted/queued run. No final report or successful campaign is
  claimed. The earlier offset-4000000 campaign belongs to the old fingerprint.

These run Godot/Node on GitHub, not Xcode Cloud. Never infer success from
dispatch or queue state. Inspect source manifests, reports and raw logs when
jobs terminate. Do not restart an existing run after an observation timeout.

## Scope limits

Integration fixtures often shorten rounds and use four scripted AI/default
arenas; race tests retain their specified laps. This is not all maps, players,
orientations, physical controls or network conditions. No sustained iPhone
frame-time, energy, thermal or memory acceptance is established here.
No main merge, production backup/migration or Railway deployment, native
archive/signature validation, Apple upload/processing or review submission
was performed. Original scope and all external gates remain open.
