# Backgrounding before a round starts

## Findings from the wider visual audit

Base commit: `c211218`, feature/kras-online-random-rotation. Before the fix,
the runtime selected-source fingerprint was `4713d46e1be342fe50320ccad49cb71e9e020c632228581e3c31b3f525cdaf5b`.

Two native-rendered campaigns each attempted all 39 default game/arena pairs
in Arabic, four human touch slots, 1280x720 and 540x960, one additional playing
second per capture. They are NOT clean passing campaigns:

- First: 78 captures, 77 passed, relic_hold/portrait failed with a pause menu
  after the real background notification.
- Second: 78 captures, 76 passed; bumper_bowl/landscape and storm_heart/portrait
  failed with the same pause condition. No previews were opened during this run,
  so image previewing alone is not established as the cause of focus loss.

The logs contain real foreground/background events. No specific external cause
is asserted. Only a sample of these 156 images was visually inspected, not all.
The old capture guard did not check Platform.is_backgrounded, so some old PASS
rows can include background scenes and must not be promoted as full visual QA.

## Capture reliability fix

`tests/stage_zero_visual.gd` now requires foreground state, a live phase, no
pause flag and no pause menu through a shared capture_is_live predicate. Reports
include app_backgrounded. A truth table covers all 12 phases and all eight
combinations of pause/menu/background (96 combinations); the existing roster
and arena matrix assertions are retained. Focused suite: 278 assertions, exit 0.

An intermediate six-capture recheck on the old gameplay found bumper_bowl in
the background with paused=false. The new guard correctly rejected it; five
other captures passed. This run is preserved as a failure, not relabelled.

## Actual gameplay defect and repair

The match only listened for background events while already live. Backgrounding
during preparation, or constructing a match after the event, allowed a local
round to become live without another event and spend unseen playing time.

The regression covers an already-backgrounded scene plus background events
during INTRO, INSTRUCTIONS and COUNTDOWN. Before the production fix: 24 passed,
16 failed; the clock fell from 95.0 to 94.5 in every affected case. After it:
44 assertions passed, including pause-menu presence, frozen clock, no automatic
foreground resume, and ordinary simulation after explicit resume.

The three-line production guard at the end of MatchScene._set_phase reuses the
existing _on_app_backgrounded path when entering a live phase while already
backgrounded. It does not replace the local/online distinction: online retains
its existing non-global-pause behavior. No scoring, AI, physics parameters or
tournament rules changed. This is not a claim that an online server was retested.

## Final qualification

- All 466 scripts compile; strict compile log guard passed.
- Full suite: 427958 assertions, 394.6 seconds, exit 0. Strict test guard passed.
  Four ERROR entries were individually inspected: deliberate failed-save fixture
  and three deliberate router-recovery fixtures.
- Final native recheck: bumper_bowl, storm_heart and relic_hold, both orientations,
  four touch slots, Arabic: six captures, zero failures, strict runtime guard
  passed. All six final images were visually inspected after the process exited.
  Every final report row was foreground/unpaused, with no pause menu.
- Rendering: Godot 4.7.1.stable.official.a13da4feb, Metal 4, Forward Mobile,
  Apple M5. This is macOS rendering, not a physical iPhone/iPad performance test.
- No code/test edits overlapped the final full or final rendering campaigns.

Final runtime selected-source fingerprint, unchanged through qualification:
`d9b760c97c4b1cb8a940507915e78452a67664d29c5aa457fdc63826085f33cf`.
It excludes tests and many assets, and is not signed-archive attestation.
Changed files were byte-matched between checkout and tested runtime:

- src/match/match_scene.gd: `e57c201aa0bf85f982912168461ed827c0baddedb66f2bd4fdf132ab8669b636`
- tests/stage_zero_visual.gd: `4efd0bbcf4909508d364f396e7535eb5a11ade558a0c8398d23515859f16ecd2`
- tests/suites/test_visual_roster_policy.gd: `6211ca55635f6a9d996c2b3e6eec2f2169c2eb4cee80d874973ebecc56233fcb`
- tests/suites/test_lifecycle.gd: `0525b6ead4893e07f442f056cb8d768f4a480b1e596b97f069ea21e779f4f805`

Completed full log SHA-256:
`08ab495f9ee54da6891bbc34ebbf8e774111caa130165c4856a1ef108bb6f6a6`.
Sibling `qualification-prelive-background-2026-10-15/` preserves all four rendered
campaign reports/logs/screenshots, red/green lifecycle, focused policy, compile
and completed full logs. Only synthetic QA artifacts were copied, not saves.

## Remaining scope

The 39-game default-map audit discovered this defect; it is not certified as a
clean 78-case final-source run. The final rendering recheck covers three games.
Other human counts, all declared arenas, physical touch ergonomics, device
energy/thermal/FPS, balance and release gates remain. Stage 0 is still
QA_PENDING/MERGE_PENDING. No main push, deployment, new signed archive, upload
or Apple review submission occurred. Production promotion still requires the
previously requested database backup/restore evidence and authorization.
