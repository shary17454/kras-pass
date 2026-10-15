# Portrait Arena Framing

Repository: shary17454/kras-pass. Branch: fix/kras-portrait-arena-framing.
Code commit: 1cbe6f366aea9445c3fcd0bfe70f7438365eff3a.
Parent: 57507b70f9728430d6a0762275ccd3bc7ed4ad87 (PR 210).

## Change and Evidence

The actual portrait Scrap Karts and Kart Sprint views flattened the floor into
a narrow strip despite considerable unused vertical space. ARENA mode now
gradually steepens its view as the viewport becomes narrow. Its portrait
projection fits inward as well as outward, so raising the camera does not
silently shrink the floor's width. Rim points, three-metre geometry and live
players still participate in the existing safe-area fit.

Landscape height and projection-fit policy, WORLD/CHASE/COURT/TOP_DOWN/ISOMETRIC
modes, arena sizes, vehicle physics, scores and input semantics are unchanged.
Camera changes may affect visible AI perception, so previous source-fingerprint
balance artifacts must not qualify this child source as current.

- Before change: world_camera suite, 826 passed, four failed readability checks.
  /tmp/kras-portrait-camera-red.log.
- Raising the angle alone passed the initial height checks but actual screenshots
  showed reduced floor width. This intermediate approach was not accepted.
- Final world_camera suite: 834 assertions passed, including new portrait width
  and height bounds plus existing translated arenas, square corners, four-touch
  safe regions, falling-player recovery and Colossus sightline tests.
  /tmp/kras-portrait-camera-fit.log.
- All 422 scripts compile. /tmp/kras-portrait-fit-compile.log.
- Final Metal rendering: 16 captures per locale, zero failures in Arabic and
  English, 32 total. Eight default arenas: scrap_karts, kart_sprint, ring_rumble,
  crumble_court, magnet_court, gem_grab, goal_guard and boss_colossus. Both
  540x960 portrait and 1280x720 landscape, one scripted human plus three AI,
  with two playing seconds before capture.
  /tmp/kras-portrait-fit-ar and /tmp/kras-portrait-fit-en.
- Manually inspected final Scrap Karts portrait in both languages and earlier
  intermediate Kart Sprint portrait; the final images show a larger floor than
  the intermediate attempt. Nonblank image checks alone are not polish approval.
- Strict log guards passed on final camera tests, compilation and both render
  logs. git diff --check passed.

The first integration run omitted the test runner's documented --fixed-fps 60
option. Its real-time partial log is retained at /tmp/kras-portrait-fit-matches.log;
it was explicitly interrupted with exit 130 to correct this test configuration,
not counted as a success. A separate fixed-step run uses
/tmp/kras-portrait-fit-matches-fixed.log and an independent save directory.

The corrected fixed-step integration run completed with exit zero: 6960
assertions passed in 244.8 seconds. Its strict completed-test log guard passed.
This covers the registered games' short four-AI match fixtures, multi-round
flow, pause/restart, device loss, paired difficulty fixtures, vehicle/item rules,
authored-world geometry, race recovery and extended three-lap AI races. It is
not the separate natural 42-match-per-game balance campaign or human device QA.
The final code files remained unchanged throughout this run and the render runs;
only this report was added afterward.

## Scope Limits

This is not all-map/all-player-count visual qualification, a long soak, battery
or thermal evidence, physical iPhone/iPad QA, a new complete balance campaign,
or certification of 39 READY games. Previous balance campaigns predate this
camera source. There is no main merge, production migration/deployment,
Xcode Cloud action, new Distribution archive, Apple upload or review submission.
