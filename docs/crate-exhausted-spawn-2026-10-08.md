# Crate Smash: Reject Exhausted Spawn Search

Parent: `8c52fb3b0e322f10a05e04e90d9fcf662ba2a1f4`.
The old spawner appended a crate at its last sampled position even when all
20 `_spot_is_free` checks failed. This violates the placement check and adds
a colliding world node. It is a reproduced safety defect, not an established
cause of the campaign spawn-slot warning.

The spawner now selects a valid position before allocating the crate body,
mesh and collision. If bounded search finds none, it returns without adding
anything. The existing 1.1-second field replenishment can retry later. Valid
spawns retain the same bomb/position RNG order, visuals, scores and rules.
No unbounded retry, protocol change, save migration or character tuning was
introduced. Player clearance is not added by this change.

## Evidence

- Regression before fix: 163 assertions passed, two failed; one rejected
  crate and an extra world child were present despite 20 rejected candidates.
  `/tmp/kras-crate-blocked-before.stdout`, exit one.
- After fix: all 165 crate/network assertions pass, including bounded search,
  empty inventory/world on failure and successful subsequent allocation.
  `/tmp/kras-crate-blocked-after.stdout`, exit zero; strict tests guard passes.
- All 429 scripts compile, strict guard passes:
  `/tmp/kras-crate-blocked-compile.stdout`.
- Natural sample at seed offset 3800000: 24 baseline, 16 mirrored difficulty
  comparisons and two smoke matches complete. Strict runtime guard passes.
  Start/end fingerprints match:
  `78820211690a799c464d58ecc589bc3c80f54b7f28ce21a06181f37783acf6b0`.
  Expert placement-point share 0.6746987952, slot bias 0.0416666667,
  character bias 0.125, no automatic flags. Both smoke modes complete.
  Report: `docs/qa/crate-exhausted-spawn-2026-10-08.json`.

The focused saturation fixture, not this small natural sample, proves the
failure-path correction. The earlier campaign warning remains retained.
Core run 37765555402 belongs to the parent commit, not this change. Current
full-source/device/performance/production and exact-source signed local
Xcode release qualification remain open. No archive or Apple upload/review
submission was performed.
