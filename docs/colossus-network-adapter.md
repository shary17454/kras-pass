# Colossus Network Adapter Checkpoint

This is an adapter checkpoint, not online qualification or release readiness.
The development room allowlist is unchanged. Production networking is not enabled.

## Implemented

- Shared match snapshots capture and validate the Colossus world.
- World schema has seven fields: boss, warnings, craters, arm_rotation,
  fist_position, fist_scale and exposed.
- Guest views reproduce the host arm, buried fist, warning rings and carved mesh.
- Guest carved floor relinquishes its physics body. Ground queries still use the
  host holes, while gameplay callbacks, damage and local crater creation are blocked.
- Hole updates are batched, deep copied and skipped for identical snapshots.
- Round baseline restores health and removes previous crater views and holes.
- Server validator bounds poses, exposure, boss state, object counts and IDs.
- Core CI requires an actual Godot Colossus capture for server schema testing.

## Evidence

- Godot 4.7.1 compile: `/tmp/kras-colossus-adapter-compile.log`, 315 scripts.
- Carved floor regression: `/tmp/kras-colossus-adapter-floor.log`, 56 assertions.
- Actual slam/arm-hit/guest adapter: `/tmp/kras-colossus-adapter-capture.log`,
  51 assertions. The real host slam creates a radius-3 hole; a rim attack reduces
  host health from 800 to 745. Guest geometry matches without a collider.
- Server: `KRAS_COLOSSUS_WORLD_FIXTURE=/tmp/kras-colossus-adapter-test-saves/colossus-world.json node --test colossus-world.test.js`,
  two passing tests, no skips.
- Shared match path: `/tmp/kras-colossus-shared-contracts.log`, 126 assertions.
  Initial and replacement baselines stay quiet, fresh damage at exactly 1000 ms
  plays once, and a 1001 ms sample updates health without replaying its sound.
  Duplicate snapshots do not recreate floor geometry. Host radius changes preserve
  holes while the guest remains collider-free. Replacement retires old view nodes.
  Malformed boss state, object IDs, object shapes and oversized populations are
  rejected by the bounded schema.
- Extended shared events/reconnect: `/tmp/kras-colossus-shared-reconnect.log`,
  139 assertions. Actual host damage crosses the first phase threshold, a host
  strike increments its sequence, and lethal host damage hides the guest boss.
  Fresh effects play once; a replacement after defeat displays the same state
  without replaying damage, phase, explosion or victory sounds. A subsequent
  round reset clears the replaced view's crater geometry correctly.
- Boss round-reset regressions: `/tmp/kras-colossus-shared-reset.log`, 429
  assertions across Forge, Colossus, Dreadnought and Sovereign.
- An earlier test used the wrong on_round_start argument count and emitted a
  runtime error despite the harness summary. That run is invalid; the corrected
  capture run completes teardown without leak diagnostics.

## Remaining Before Online Qualification

- Add room authority/resume/result contracts before enabling the room allowlist.
- Run real two/four-client matches, reconnects, tournaments and tied finals.
- Run full project regression and inspect geometry/network scheduling budgets.
- Physical iPhone orientation, FPS, energy and thermal measurements remain required.

No health, damage, authored attack periods or recovery windows were changed.
No archive, signing, App Store upload or review submission is part of this checkpoint.
