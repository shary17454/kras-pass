# AI Camera Frustum

Runtime parent: `36bd19b5711330cbbe02f28e1008be1883a2363a`.
Branch: `fix/kras-ai-camera-frustum`.

## Implementation

MatchContext now exposes the match's observation camera. AIBrain's shared
visibility guard rejects out-of-frame points, points behind the camera, near/far
clipping, and hidden visual layers. Direct meshes can straddle the frame: their
AABB endpoints are tested if their origin lies outside. Other Node3D roots use
their origin; this is not a full child-mesh silhouette visibility solution.

Shared cameras use the shared frame. WORLD/CHASE follow views translate and
rotate target coordinates into an equivalent view around the bot's own current
position and heading, rather than using another player's world position. No
additional rendered camera nodes are allocated. Terrain collision adjustment
for a separately simulated bot camera is not implemented by this mapping.

The actual Node3D camera transform and Camera3D projection are used together.
An initial headless probe showed `get_camera_transform()` returning identity
before the render update while `global_transform` was already positioned above
the arena. The initial native-frustum and cached-transform attempts rejected
nearby valid targets and failed tests. They were not counted as passing.
Probe logs: `/tmp/kras-camera-ai-probe.log`,
`/tmp/kras-camera-ai-clip-probe.log`.
API reference: [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html).

Bomb observation history and current actionability now apply the same shared
guard. Specialized controller queries elsewhere still require separate audit.
Reaction history, scoring, character stats, and human controls are unchanged.

## Verification

- Final AI visibility suite: 2085 assertions passed; log guard passed.
  `/tmp/kras-camera-ai-final-bombs.log`.
- World camera boundary suite: seven assertions passed; log guard passed.
  `/tmp/kras-camera-ai-framing.log`.
- Cases include before-first-render visibility, out-of-frame, behind-camera,
  near/far planes, partial direct mesh, cull layers, bot-relative follow camera,
  shared camera, orthographic camera, and out-of-frame bomb history rejection.
- The history-wrap fixture now moves within the actual frame and explicitly
  asserts visibility for every observation. The elevated-ledge fixture moves its
  camera to the elevated venue rather than expecting an off-screen target.
- Partial-mesh placement is derived from the actual camera projection, not a
  hardcoded viewport aspect. This is not rendered screenshot QA across devices.
- `git diff --check` passed.

## Remaining Gates

No wall occlusion, HUD-overlay occlusion, complete child-mesh silhouette, or
all-specialized-controller coverage is claimed. Detached contexts without an
observation camera retain the previous visibility-only behavior; actual matches
set their camera before creating brains. Full all-game regression and new
natural-duration balance samples must qualify this behavior change. Previous
Fawda balance results do not prove this source's balance. Mobile performance,
portrait/landscape pixel QA, physical controllers, production Online, and the
exact-source distribution/review pipeline remain outstanding. No main merge,
archive, upload, processing, or Apple review submission occurred here.
