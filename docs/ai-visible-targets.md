# Shared AI visibility boundary

Runtime source: `181491a` on `feature/kras-ai-visible-targets`, based on
`53b8ba0` from PR #4. No main merge or production Online activation is implied.

## Reproduced behavior

The shared nearest/leader/edge selectors could choose hidden fighters.
Pickup selection queried availability on hidden nodes, including children
whose parent was hidden. Without history, perception fell back to a hidden
fighter's live position/velocity. History also sampled hidden bodies.

The initial focused fixture `/tmp/kras-ai-visibility-before.log` failed ten
assertions with three passing. It confirmed hidden target selection, hidden
availability queries and live fallback leakage. The final fixture also advances
time beyond its latest sample, exercises ring wrap, reaction delay and queued
deletion; these additional assertions were not part of the initial count.

## Repair

`AIBrain.can_observe` rejects missing/freed nodes, queued deletion and explicit
render-tree invisibility. Shared rival selectors, attack decisions, buff reads
and group lookup apply it before reading target state. Hidden history entries
retain only the newest last-visible position and zero velocity; unseen hidden
bodies have no live fallback. No reaction profile, movement speed, character
stats or score award changed. History remains capped at 32 samples.

This is not camera-frustum or wall-occlusion visibility. It does not introduce
a fully isolated Perception Layer for every controller-specific brain API.
At this shared-helper revision, custom selectors still needed review, including
Collector `_preferred_loot`, Duo `_pick_target`, and direct ball/hazard/controller queries. Do not label all
AI fair or all games balanced based on this shared-helper repair.

## Verification

- `/tmp/kras-ai-visibility-final.log`: 19 focused assertions passed.
- `/tmp/kras-ai-visibility-compile.log`: 323 scripts compiled.
- `git diff --check`: passed.
- Compared all 349 tracked `.gd`, `.tscn`, `.json` and `.tres` files under
  `src`, `tests` and `data` with the runtime checkout: zero mismatches.
- `project.godot` matched SHA256
  `1b2543beb1823d39ceca8f0c3590383da417863f22d4b54b21faaeb4acf6f02f`.
- Source and runtime AI SHA256 matched
  `1e347d99d2f9b29b068d5ba550ec2a04f637ee65f96f56630139b128fc517c40`.

Full regression `/tmp/kras-ai-visibility-regression.log` finished successfully
with 21,081 assertions and exit code zero, using isolated storage
`/tmp/kras-ai-visibility-regression-save`. It completed the existing game
integration, all eight actual three-lap race checks, replay, save, input,
lifecycle and presentation suites, including the new visibility fixture.
Its runtime content matched source
`181491a1149beb9e303b3e282b23853346411f28` as verified above.

The server group used all six freshly generated world captures from that
regression. `/tmp/kras-ai-visibility-server.tap` initially recorded 119 passing
tests and one failure: the sandbox denied a temporary `127.0.0.1` listener
with `EPERM`. The same unchanged group, run with local-process permission,
passed 120 tests with zero failures/cancellations/skips in
`/tmp/kras-ai-visibility-server-local.tap`. No production account or database
was used by these tests; the socket listener is loopback-only and ephemeral.

The wall-clock duration was 1,227 seconds; the cause of the local variability
has not been established and this is not a performance acceptance result.
No script/parse/assertion or ObjectDB/resource/RID leak pattern was found in
the full log. The two error entries are local macOS CA retrieval and the
intentional failed-write save fixture. Focused/compile logs also retain that
CA error. Do not claim a clean CA environment or signed-device connection.

These are not four-independent-peer, signed-device, Internet, battery/thermal
or App Store submission results. Dedicated AI balance simulations, custom
perception paths and the complete network matrix remain unqualified.

## Custom collector and team selectors

Follow-up branch: `feature/kras-ai-custom-visible-targets`, based on `67620dd`.
Collector filters invisible/queued pickups before availability queries and
ignores hidden rivals when calculating contested loot. Duo applies the same
visibility guard in both edge-priority and nearest-opponent paths, while keeping
the existing team exclusions. No movement, difficulty, points or team rules change.

The initial expanded fixture failed 11 checks with 20 passing in
`/tmp/kras-custom-ai-before.log`. A separately constructed team controller leaked
in that test fixture; explicitly freeing it removed the leak. The final fixture
also gives the collector a previously observed rival before hiding that rival,
so stale last-seen proximity cannot continue to penalize visible loot.

Verification of this follow-up:

- `/tmp/kras-custom-ai-final.log`: 31 assertions passed, exit zero.
- `/tmp/kras-custom-ai-compile.log`: all 323 scripts compile, exit zero.
- `/tmp/kras-custom-ai-party.log`: 4,117 assertions passed, exit zero.
- `/tmp/kras-custom-ai-duo.log`: 101 assertions passed, exit zero.
- Logs retain the macOS system CA retrieval error. No script or resource leak
  error appeared in these final test logs.

The full 21,081-assertion run above belongs to `181491a`, not this follow-up.
The latest observed CI run for `67620dd`, `37100912388`, had successful core,
ring and goal jobs, with other network jobs running or queued. That does not
qualify this follow-up source. No CI run was cancelled to obtain these results.
At that follow-up, Duellist, Smasher, ball/hazard/controller-specific perception, full balance,
Internet/device testing and the Apple release gates remain unfinished.

## Rendered crate cues and duellist targets

Follow-up branch: `feature/kras-ai-rendered-crate-cues`, based on `159d773`.
Smasher previously read `entry.bomb` despite its comment promising a visible
colour cue. It now reads the actual visible primary crate mesh material.
`MeshFactory.crate` names that mesh `CrateBody`; geometry/materials, gameplay
bomb flags and network schemas are unchanged. Missing/hidden visuals are not
classified. Difficulty accuracy still controls mistaken colour classification,
and a visible crate keeps its judgement between decisions. Round reset and
pruning removed/unobservable entries bound the judgement cache to observed crates.
Duellist now excludes hidden/queued rivals before target ranking.

The first fixture incorrectly used plain Node3D crates, causing a cleanup
script error; `/tmp/kras-crate-ai-before.log` is not valid qualification.
After using StaticBody3D, the valid unchanged-code baseline
`/tmp/kras-crate-ai-before-valid.log` failed 12 checks with 32 passing and no
cleanup script error. The final fixture adds cached-judgement and accuracy-zero
checks, so its assertion count differs from the baseline.

Verification of this follow-up, all terminal exit zero:

- `/tmp/kras-crate-ai-final.log`: 46 focused assertions.
- `/tmp/kras-crate-ai-compile.log`: all 323 scripts compile.
- `/tmp/kras-crate-ai-rounds.log`: 92 crate lifecycle assertions.
- `/tmp/kras-crate-ai-network.log`: 125 crate presentation assertions.
- `/tmp/kras-crate-ai-duel.log`: 39 duel presentation assertions.

These final logs retain the macOS CA retrieval error, with no script or resource
leak errors. The prior full regression is not evidence for this new source.
This is a rendered-material cue, not an isolated full Perception Layer with
occlusion, object observation delay or camera-frustum checks. Ball/hazard and
other custom controllers, full balance, four-peer Internet qualification,
physical-device QA and all Apple release gates still require completion.

## Ball, carrier and platform selection

Next commit on `feature/kras-ai-rendered-crate-cues`, based on `d689f16`:

- Blast bot filters hidden/queued balls and requires GameBall nodes, and does
  not select hidden opponents from their previously observed positions.
- Courier excludes hidden loaded rivals while retaining the nearest visible
  fallback when nobody visible is carrying items.
- Platform bot excludes hidden tiles from targets and neighbour scoring, drops
  a cached target after it disappears, and ignores hidden rival occupancy.
- AIBrain's header now describes the actual partial visibility boundary rather
  than incorrectly asserting every query is already isolated by construction.

The initial platform fixture assigned an untyped Array to a typed Arena.tiles
property; `/tmp/kras-world-ai-before.log` includes that script error and is not
valid qualification. Correcting the fixture without changing runtime source
produced `/tmp/kras-world-ai-before-valid.log`: 49 passing and 12 failing
assertions. The final fixture adds two cached-platform recovery checks.

Terminal verification for this source:

- `/tmp/kras-world-ai-final.log`: 63 assertions passed, exit zero.
- `/tmp/kras-world-ai-compile.log`: 323 scripts compiled, exit zero.
- `/tmp/kras-world-ai-blast.log`: 94 assertions passed, exit zero.
- `/tmp/kras-world-ai-collection.log`: 99 assertions passed, exit zero.
- `/tmp/kras-world-ai-crumble.log`: 2,512 assertions passed, exit zero.

The final logs retain the local macOS CA retrieval error. These tests do not
qualify object-motion observation delay, occlusion, all custom brain queries,
full balance or physical-device performance. Further inspection still finds
custom fighter loops in Siege, Zone, Bomber, Armed Racer and Climber, and direct
ball queries in Keeper/Magnet Keeper. Each needs semantic review and tests.
The prior full regression is still older-source evidence, not a pass for this
commit. No main merge, production Online activation, archive or Apple upload
has occurred for these follow-ups.

## Remaining explicit-visibility queries

Next commit on the same review branch, based on `b2cda0d`, covers the remaining
enumerated custom rival loops in Zone, Bomber, Armed Racer, Climber and Siege.
Hidden remembered rivals no longer trigger zone attacks, mine timing, bomb
collection or climbing detours. Hidden static ledges are excluded. Keeper and
Magnet Keeper now reject hidden/queued balls before threat/count calculations.
The Fawda `bomb_states` perception API omits hidden/queued ordnance before reading
its position/fuse; the actual simulation and network snapshots are unchanged.

Siege exposes `base_visible` as a render-tree query. A visible crystal remains a
valid target even if its owner is hidden; hidden crystals are not targets. This
does not change health, damage, rewards or authoritative world state. The keeper
header no longer claims ball motion is already sampled with reaction delay.

Initial focused baseline `/tmp/kras-other-ai-before.log`: 68 passed, 15 failed,
exit one, with no fixture script or leak errors. The final count adds the visible
bomb position assertion that could not run when the baseline returned three
bombs rather than one.

Terminal verification, all exit zero:

- `/tmp/kras-other-ai-final.log`: 84 assertions.
- `/tmp/kras-other-ai-compile.log`: 323 compiled scripts.
- `/tmp/kras-other-ai-siege_network.log`: 129 assertions.
- `/tmp/kras-other-ai-siege_final_evidence.log`: 13 assertions.
- `/tmp/kras-other-ai-zone_hold.log`: 35 assertions.
- `/tmp/kras-other-ai-fawda_network.log`: 130 assertions.
- `/tmp/kras-other-ai-armed_race_network.log`: 176 assertions.
- `/tmp/kras-other-ai-tide_network.log`: 28 assertions.
- `/tmp/kras-other-ai-goal_guard.log`: 120 assertions.
- `/tmp/kras-other-ai-magnet_network.log`: 190 assertions.

Final logs retain the local macOS CA retrieval error, with no script/resource
leak errors. Latest observed PR #4 source `53b8ba0` CI had 31 successes, zero
failures, three running and six queued; this is older-source evidence, not a
pass for this follow-up. No job was manually cancelled/restarted to obtain a
pass. Ball/object motion delay, tagged/relic/controller-specific semantics,
occlusion, full-source regression/balance/network matrix and device/release QA
remain unfinished. Explicit visibility guards are not proof of all AI fairness.
