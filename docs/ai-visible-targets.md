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
Custom selectors still need review, including Collector `_preferred_loot`,
Duo `_pick_target`, and direct ball/hazard/controller queries. Do not label all
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
