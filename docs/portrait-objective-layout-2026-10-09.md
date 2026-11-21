# Portrait objective header - 2026-10-09

## Observed defect

The current-source visual smoke on f0f2f32e528b69ec497b5b1c609540aa7b4249be
captured 39 default arenas in Arabic, one touch player plus three AI, in
landscape and portrait. Its 78 automated nonblank/control-bounds checks passed,
but manual inspection found the portrait objective over the playable court
in crumble_court. Fixed offsets (460, or a special 230 for goal_guard) ignored
the actual responsive header height. Automated rendering success was not proof
of unobscured gameplay.

## Change

- Portrait objective placement now follows occupied_top() plus a 12-pixel gap,
  retaining existing auxiliary-overlay reservation and multiplayer control
  layout. Landscape placement is unchanged.
- Existing catalog HUD tests cover all 39 definitions, Arabic/English and
  portrait/landscape; new portrait assertions bound the objective to the header
  strip after layout settles and the normal HUD tick runs.
- Rendering smoke now rejects paused matches, pause menus and non-live phases;
  each screenshot report records both pause flags. Runtime phase alone is
  insufficient: the pause UI may be present while phase remains PLAYING.

## Verification

- New regression assertions failed on the prior fixed-position HUD.
- Focused status_toast_hud suite: 3841 assertions passed, exit 0.
- A first local sandbox engine launch aborted (134); the authorized local
  macOS headless launch ran the tests. No environment crash is treated as a
  product test pass.
- Guarded post-fix captures: tank_arena, crumble_court, goal_guard, both
  orientations. Five passed; one tank portrait was correctly rejected as
  paused. Retrying tank_arena alone passed both orientations with no pause
  flags. The rejected screenshot is retained, not relabeled successful.
- Manual post-fix crumble portrait shows the objective above the court without
  covering the players. This is desktop rendering, not physical-device QA.
- Full fixed-FPS regression: 396247 assertions passed in 212.9 seconds,
  exit 0; completed-log guard passed. Raw log: /tmp/kras-objective-full.stdout,
  also copied to the qualification evidence directory.

## Release boundaries

This does not certify all maps, all player counts, touch usability, iOS devices,
performance, energy, heat or every product requirement. The initial all-39
smoke predates the pause guards and must not be called complete gameplay QA.
The prior local Xcode 27 archive from f0f2f32 does not contain this runtime fix.
Any release using the change needs a committed source, affected/full tests,
fresh export attestation and archive, then independent production and Apple
gates. No main merge, production deployment, upload or review submission here.

Evidence root outside the repository:
../qualification-objective-layout-2026-10-09/
