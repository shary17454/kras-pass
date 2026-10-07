# Vehicle collision initialization and slow-contact investigation

## Scope

This change does not qualify the application for App Review. It investigates an
actual vehicle collision initialization defect and rejects the box-shape fix
after a severe rendered performance regression. It retains bounded opt-in debug
evidence for slow `move_and_slide()` calls, an Echo AI fix and test-fixture cleanup.
No terrain geometry, physics backend,
network protocol, production environment, or signing identity is changed.

## Findings

At source `96688f6b4400ae1bf15727473da91cf4aef0eba8`, `MatchScene` adds a newly
created fighter to the tree before calling `setup`. `_ready()` creates a walking
capsule while `locomotion` is still WALK. The later DRIVE setup changes movement
and visuals but never replaces that capsule with the authored vehicle box.
Conversely, setup before entering the tree can produce a box. The same vehicle
therefore had different collision geometry depending on initialization order.
Vehicle scaling also changed box dimensions without scaling its vertical offset.

The new regression failed before the fix: 9 assertions passed and 3 failed.
With the experimental box fix, all 17 assertions passed, including both initialization orders,
authored box dimensions/offset, scaling, walking reconfiguration, retention of
the existing collision node, and preservation of the active size modifier.
Raw logs: `/tmp/kras-collision-mode-before.log` and
`/tmp/kras-collision-mode-after.log`. The latter passed the Godot log guard.

## Full-suite regression investigation

The first complete run failed with 385651 assertions passing and three terrain
traversal failures. A standalone terrain run passed. A second complete run with
opt-in contact output reproduced the failures (224.7 seconds). It showed four
anonymous CharacterBody3D fixtures, not terrain normals, stopping the driver near
x=-1.121. They came from the collection context created by the Mutators
compatibility test: only its first context was cleaned up, leaving all four
fighters and the power-up node alive until process exit. The wider vehicle hull
exposed that existing fixture contamination.

The compatibility test now retains and cleans both contexts, with an assertion
that the host's original child count is restored. The terrain traversal threshold
and physical ground-contact assertions are unchanged. Optional `--terrain-debug`
output is retained for investigation and is not emitted during ordinary runs.
Failed logs remain `/tmp/kras-collision-mode-full.log` and
`/tmp/kras-collision-mode-full-debug.log`; standalone attribution is recorded in
`/tmp/kras-box-terrain-probe.log`. The post-cleanup full run must pass independently.

The first post-cleanup run passed terrain traversal but ended with 385654 passed
and one failure: actual Echo AI movement could not complete [0, 0, 1]. The same
failure reproduced standalone (49 passed, 1 failed), so it was not dismissed as
test contamination. Four players targeted the same pad center and blocked entry
or departure. Echo now offsets the approach point by 0.9 units inside the visible
2-unit pad, based only on the player's own slot and roster size. It still recalls
the visible sequence with the original delay/error policy; no hidden-answer read,
speed advantage, or longer input window is added. The unchanged Echo suite then
passed 50 assertions and the log guard. Logs: `/tmp/kras-collision-echo.log` and
`/tmp/kras-collision-echo-spread.log`.

The box experiment is `3fcf8a5`; the independent Echo approach fix is `3306669`
and fixture cleanup is `8529d71`. The box experiment and its shape-specific test
were reverted normally by `cbbea41`, with no history rewrite. The initialization
order defect remains open; a consistently configured vehicle hull still needs an
appropriate terrain-contact implementation and measured acceptance.

## Rejected box experiment

Source `33066698c3a6cd603443db5c3b01e01e4117e3d4` passed compile (414 scripts),
inventory (507 resources, 22 autoloads, 27 routes, 8 characters, 0 structural
issues), all 385655 assertions in 329.3 seconds, independent three-lap race,
six boss regressions and 39 stability matches (0 failures). Full command exited
0. Evidence is `/tmp/kras-collision-mode-qualified.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.ZUvoaZ`.
That is test evidence for the REJECTED source, not for the final reverted revision.

The separate actual Metal Mobile probe then regressed to 1.179 FPS, p95
1355.556 ms, p99 1382.675 ms, worst 1419.925 ms. Character physics took up to
142.301 ms per recorded call; only 6.5 seconds of simulation progressed during
33.266 seconds of live wall time. The JSON `vehicle-box-rejected-four-high.json`
is retained in full. Probe exit and Godot log guard were 0, but that does NOT
constitute performance acceptance. No concurrent owned qualification process
was running. The experiment was rejected despite green unit/integration tests.

## Slow-contact evidence

`physics-contact-four-high-before.json` is a real Metal Mobile rendering probe:
Godot 4.7.1 a13da4feb, Apple M5, 1280x720, HIGH, cap 60, tank_oasis, four scripted
human Touch sources, no Bots, four personal views. It completed a 3-second warmup
and 30-second steady sample. It is not a physical iPhone performance test.

Measured steady FPS: 27.91; p95 frame interval: 154.437 ms; p99: 211.292 ms.
The eight retained slowest character-physics records all report TerrainCollision
and slot 3 at approximately (-28.862, 0.110, 4.637). Maximum recorded character
physics interval was 35.828 ms. Contacts are collected after the measured call,
not added to its elapsed time. This is attribution evidence, not proof that this
body alone accounts for every frame stall or that the collision fix improves FPS.

Diagnostics retain at most eight samples and eight contacts per sample, with
bounded node names and no user/account data. They are disabled unless an allowed
debug session explicitly requests operation tracing. The dedicated contact pool
is independent of inclusive match-tick samples so those cannot evict all physics
attribution records. Its focused suite passed 27 assertions before the collision
fix; the final revision still requires the complete test run recorded below.

A read-only local probe reports `physics/3d/physics_engine = DEFAULT`, enhanced
Jolt motion-query edge removal true, and separate-thread physics false. The
server class alone does not identify the resolved backend. These observations
are not permission to change the backend across 39 games. The first sandbox
probe failed opening the default log path; its retry with an explicit temporary
log returned settings but also a macOS CA-access diagnostic. Accepted regression
tests use the local session and isolated logs/saves, not that failed probe.

## Final retained-source qualification

Source `cbbea41` restores fighter collision initialization and scaling exactly
to `96688f6` (verified by Git diff). Only the bounded diagnostic calls remain in
the fighter relative to the pre-diagnostic base. The accepted gameplay change
is Echo approach separation; the fixture cleanup and optional terrain contact
prints are testing changes. The shape-specific experimental regression test was
removed with the rejected box experiment, not weakened into a passing test.

Final `tools/check_party.sh` exited 0:

- 413 scripts compile.
- 506 resources, 22 autoloads, 27 routes, 8 characters: 0 structural issues.
- All 385639 assertions pass in 282.1 seconds.
- The independent race and all six boss regressions pass.
- 39 stability matches, 0 failures; cache release checks complete.

Evidence: `/tmp/kras-contact-final-qualified.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.4lurim`.
Runtime/data/test files were verified unchanged against the final commit after
the run. The cache-release sample is not a long-duration memory-leak guarantee.

The final separate Metal Mobile probe completed, exited 0 and passed the log
guard: `/tmp/kras-contact-final-render.log`. Full JSON is retained in
`physics-contact-four-high-final.json`. It measured 54.727 FPS, p95 26.055 ms,
p99 47.754 ms, worst 151.542 ms, 14 frames above 50 ms. Simulation progressed
32.867 seconds during the live sample; scene nodes remained 51 before/after.
This is NOT stable 60 FPS acceptance or iPhone/battery/thermal qualification.

The final worst character physics sample is 68.048 ms at RockCover9, slot 0,
near (5.612, 0.318, -10.699); another cluster touches RockCover3, slot 3,
near (-23.712, 0.580, 27.351), including mixed terrain/rock contacts. The earlier
sample localized slow contacts to terrain. Therefore the investigation must
include terrain AND cover collision, not optimize only one based on one sample.
Diagnostic contacts cannot establish the cost of every collision candidate.
The change does not claim to improve tank FPS: the final tank geometry is the
same as the earlier diagnostic sample, and previous captures show substantial
machine/run variance. The rejected box's severe slowdown remains unacceptable.

## Release gates

All-game integration/race/stability validation and a separate rendered probe must
complete before considering this a candidate fix. Collision shape changes can
affect overlaps, handling, AI outcomes, and saved-input replay trajectories;
previous-source balance results cannot qualify this source. Existing saved
progress is not intentionally changed. Archive 1.1.11 (109) predates this source
and the personal-view fix; it must not be uploaded as the latest implementation.

Native-device performance, approved production synchronization, final-source
local Xcode 27 Distribution archive, upload/processing, and actual App Review
submission remain separate unverified gates.
