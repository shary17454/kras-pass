# Tank Cover Shape Reuse and Release Checks

Runtime tested: `7e8f012ec4cddb193d595073cdb306b0e53f5fca`.
Branch `perf/kras-tank-cover-shape-reuse`, based on the unmerged color-arrival
branch head `854ef870983be928718ae88602fc79f2548e2aa3` (PR 84).

## Runtime Change

Each of the 16 rock covers previously generated a fresh convex collision hull,
even when using an identical imported mesh. The three tank maps use six rock
meshes. A world-local dictionary now generates one immutable hull per mesh:
six instead of sixteen, without a process-global cache or retaining previous
worlds. Every cover keeps its own body, transform, offset and scale. The cache
lives only as long as the world. No visual geometry, physics parameters,
navigation routes, network schema or content was removed or simplified.

The original focused test passed 178 assertions and failed 30 repeated-hull
identity assertions. The final expanded test passes 244 assertions across the
three maps: shared hull identity, distinct meshes retaining distinct hulls,
exact generated hull points, all 16 covers, transforms and actual floor rays.
Logs: `/tmp/kras-tank-cover-reuse-before.log`,
`/tmp/kras-tank-cover-geometry-fixed.log`.

## Exact-Source Regression

Full wrapper exited zero: 370 scripts compiled; 410 resources audited with
zero issues; 360061 assertions passed in 224.8 seconds. The actual three-lap
race, six natural boss probes and all 39 single-cycle stability matches passed.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.ZyKEY3/`.
Server tests with all six fresh Godot world captures: 192 passed, no skips or
failures. Log: `/tmp/kras-tank-cover-server-captures.log`.

## Rendered Inspection and Performance

Before this hull patch, source 854ef87 ran the actual Metal Mobile renderer on
Apple M5. Stage-zero visual smoke captured the default arena of all 39 games
in Arabic, one touch-configured human plus three bots, in landscape 1280x720 and
portrait 540x960. All 78 captures passed the existing nonblank/error checks;
the lowest sampled color count was 462. Evidence:
`/tmp/kras-visual-854ef87/visual-report.json` and its `screenshots/` directory.
Tank landscape, Goal Guard portrait, Color Stand both orientations and armed
race portrait were inspected individually. This is opening-state smoke, not
manual approval of every screenshot, map, player count, hazard or result state.

The same source's five-game rendered performance probe required at least ten
actual simulation seconds and 400 post-warmup samples. All five met the budget.
Log: `/tmp/kras-render-perf-854ef87.log`.

| Game | Mean ms | p95 ms | Worst ms | Setup ms |
| --- | ---: | ---: | ---: | ---: |
| tank_arena | 8.57 | 9.40 | 45.47 | 4807 |
| sabaq_sawarikh | 8.39 | 9.27 | 29.60 | 1089 |
| color_stand | 8.33 | 9.19 | 10.85 | 26 |
| goal_guard | 8.35 | 9.17 | 18.83 | 568 |
| boss_forge | 8.54 | 9.24 | 92.99 | 36 |

The first after-patch exploratory two-tank run overlapped headless regression
work; it is not an isolated performance comparison. After the full wrapper
finished, a second rendered process sampled tank twice, with the same seed,
roster, renderer and resource preparation, without those concurrent checks:

| Sample | Mean ms | p95 ms | Worst ms | Setup ms |
| --- | ---: | ---: | ---: | ---: |
| First tank | 8.48 | 9.44 | 28.85 | 2492 |
| Repeated tank | 8.37 | 9.24 | 18.67 | 751 |

Log: `/tmp/kras-render-tank-7e8f012-isolated.log`; runtime log guard passed.
Both runs met the full sample budget, all four fighters moved, and teardown
returned to 50 nodes from 50. The captured final tank frame was inspected at
`/tmp/kras-perf-tank_arena.png`. These small measurements, affected by warm
driver/resource caches, do not establish a causal speedup percentage, leak
freedom, stable 120 FPS, iOS RSS/GPU usage or battery/thermal behavior. Synchronous
setup still takes seconds and frame spikes remain actionable release concerns.

## Current Production Inspection

Main source remains `9d4580872c3585d8fd56ff0eca41cb3f595f45a1`, not this
development branch. Railway deployment `2a3bda3c-4ceb-46d4-9730-d086c6c30340`
was verified SUCCESS on that exact commit, repository shary17454/kras-pass,
branch main, effective health path /health. Instance
`a2094256-8697-44de-8d7e-d56152349c3c` was RUNNING. A bounded 50-line startup
log sample showed volume mount and node startup without an application error.
No duplicate deploy or production configuration change was issued.

Production /health returned ok and authentication_ready true, with multiplayer
still disabled. Required Apple/account variable presence, client/team/owner
matching, EC private-key parsing and persistent database path checks passed
without displaying values. The first local summary command had a JavaScript
syntax error and was corrected; it did not change production variables.
Readonly SQLite quick_check was ok, foreign-key errors zero, user_version zero.
This is the current schema, not migration or restore certification. Unauthenticated
GET /account returned 401/sign_in_again; POST /auth/apple/challenge returned 200
with the expected field types, without displaying challenge values. These
contract probes are separate from real Apple-user authentication.

Fresh Xcode 27 devicectl inspection showed the physical iPhone 16 Pro Max
unavailable; listed simulators were shut down. No device app was overwritten.
This patch is not merged to main, deployed, archived, uploaded or submitted to
Apple. Physical device QA, all-game fair perception/balance/content polish,
Internet multiplayer/reconnect and the remaining product/release gates are
still required. The complete objective remains unfinished.
