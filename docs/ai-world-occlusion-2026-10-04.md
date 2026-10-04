# AI World Occlusion

Source parent: `8f0742cca15e1477908e68f5c46bd14032b82db5`.
Branch: `fix/kras-ai-world-occlusion-v2`.

## Scope

The shared AI visibility predicate now intersects the camera-to-cue segment
against world collision layer 1. Follow-camera rays use the inverse of the
existing bot-relative view mapping; shared views retain the shared camera.
Players and pickup areas do not become opaque world obstacles. The query
resource is reused per brain. Invisible or camera-culled geometry and collision
proxies without visible descendant geometry are skipped, with eight queries
maximum per candidate point. Exhaustion fails closed. Actor mesh hierarchies
are traversed in child order with a 32-node/12-corner budget; fighters also
expose their body centre above ground. Terrain collision proxies explicitly
link their sibling render mesh via the `observation_mesh` NodePath metadata.

World-body collision is a conservative visibility approximation, not rendered
pixel visibility. Decorative geometry without a world collider, transparent
materials, HUD overlap, and complete child-mesh silhouettes remain separate
qualification work. Bot-specific terrain adjustment of a follow-camera pose
is not simulated. No difficulty, movement, damage or scoring bonuses were added.

## Diagnosis And Evidence

The first existing AI visibility regression run failed 18 assertions. A
temporary ray probe showed floor hits exactly at requested ground-contact
points, not an intervening obstacle. Non-zero-normal surface contact at the
ray endpoint is now accepted within 1 mm. Starting inside a wall and targets
buried behind a surface remain blocked. The probe was removed from runtime.

- `/tmp/kras-ai-occlusion-regression.log`: first failure, retained.
- `/tmp/kras-ai-occlusion-probe.log`: diagnostic probe, retained.
- `/tmp/kras-ai-occlusion-regression-final.log`: 2085 assertions passed and log
  guard passed after the endpoint correction, before the normal guard addition.
- `/tmp/kras-ai-occlusion-terrain-final.log`: 18 assertions passed.
  Real physics fixtures cover opaque walls, partially exposed meshes, hidden
  mesh/cull layers, player layers, target-owned colliders, starting inside a
  wall, floor endpoint contact, buried targets, exposed/hidden child meshes,
  sibling terrain association and removal.
- `/tmp/kras-ai-occlusion-source-final-visibility.log`: final-source shared
  perception regression, 2085 assertions passed.
- `/tmp/kras-ai-occlusion-compile-final.log`: all 330 scripts compile.
- `/tmp/kras-tank-terrain-final.log`: final-source tank suite, 156 assertions
  passed. The synthetic fixture moves its camera by the subject's teleport
  displacement and explicitly asserts both ammo cues are observable. Original
  behavior assertions, including route obstruction, remain in place.
- `/tmp/kras-ai-occlusion-difficulty-mesh.log`: the original difficulty-only
  test passed both collection comparisons (16 matches across eight mirrored
  seeds per game, three assertions including suite selection). This was after
  child-mesh support and before sibling-terrain linking; it is not final-source
  all-game balance qualification. No test threshold or AI tier was changed.

The first full regression run is recorded separately in
`/tmp/kras-ai-occlusion-full-suite.log`: terminal exit 1, 29747 passed and three
failed in 1748.1 seconds. It retained the initial AIBrain script while later
test scripts were edited during the run. It is diagnostic mixed-revision
evidence, not qualification of this final source. One failure was the original
collection comparison (Expert 56 / Easy 63); two were newly added child/sibling
geometry assertions against the previously loaded implementation. Focused
fresh-process runs above pass the corrected behavior. A fresh immutable-source
full run remains mandatory; these numbers must not be reported as a green full
suite. These are headless tests, not iPhone performance, thermal, battery, or
rendered portrait/landscape evidence.

## Release Gate

Main CI run `37168808464` on parent source has a failed `godot` job:
29726 assertions passed and five tank-ammo assertions failed. Its complete job
log is `/tmp/kras-8f0742c-core-job.log`. The fixture teleported its follow target
without moving the observation camera; the corrected fixture now passes the
156-assertion fresh-process test without bypassing shared visibility. The network jobs
are independent and must not be inferred successful from this result.

No main merge, new distribution archive, upload, processing or Apple review
submission is claimed for this branch. Full regressions, new natural balance
samples, Internet multiplayer, physical iPhone QA and exact-source release
evidence remain required.
