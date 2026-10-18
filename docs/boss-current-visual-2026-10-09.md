# Boss visual qualification - 9 October 2026

Tested clean checkout e6917a400bcb8d5f0a4c774b6edd5b7eced0d5ee,
with unchanged simulation fingerprint a33587770b6fbe8bc48988c0b8f0ad0a41c3e96337d8be9eb418787e23661959.
Actual Godot 4.7.1 Metal Forward+ renderer on Apple M5, not headless rendering.

Command: `godot --path . --fixed-fps 60 --log-file <isolated-log> tests/stage_zero_visual.tscn -- --games=boss_forge,boss_colossus,boss_dreadnought,boss_sovereign --locale=ar --humans=1 --play-seconds=10 --test-data-dir=<isolated-save>`.

The first run saved eight captures: four default boss arenas at 1280x720 and
540x960, one touch player and three bots. Seven passed. Colossus landscape
failed with paused=true following a logged background notification; process
exit was 1. This original failure is preserved. A targeted colossus-only run
with identical parameters and a separate save captured both orientations:
two passed, zero failures, exit 0. Both engine logs passed the repository
log checker; that alone does not override the first visual failure.

Independently inspected Forge portrait, Colossus portrait, Dreadnought landscape
and Sovereign landscape images. Arena geometry, warning markers, scores and
touch actions render; no obvious text/control overlap was observed in these
four inspected images. Boss visual models remain simple and need polish.
Nonblank captures and controls inside bounds do not prove high graphical
quality, every camera moment, every map, four-touch usability or device FPS.

Preserved evidence outside Git:
- `../qualification-boss-visual-2026-10-09-first/`: initial report, eight PNGs,
  original engine log and isolated development saves.
- `../qualification-boss-visual-2026-10-09-recheck/`: two targeted PNGs, report
  and engine log.

No shipped code, graphics, balance, dependencies or production data changed.
No physical device installation, main merge, deployment or Apple submission.
These results do not mark any minigame READY or any development stage DONE.

Separately, the completed blast_ball artifact from ongoing run 37939933912
matches checkout 76813931a747040469036e44e4e7de0d386ee109 and fingerprint
a3358777. At seed offset 8000000 it completed 24 baseline matches, 16 paired
difficulty matches and two mutator/chaos matches, with expert_edge 0.5625 and
no flags. Source start/end and checkout were checked; all three artifact logs
passed strict checks. This partial 42-match result does not erase prior
difficulty warnings or qualify the incomplete all-39 campaign.
