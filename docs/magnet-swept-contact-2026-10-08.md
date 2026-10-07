# Magnet first-contact arbitration

## Reproduced defect

`MagnetCourt._tick_ball` previously awarded a swept capture to the first active
keeper in roster order whose catch circle intersected the segment. Adjacent
keepers can legally overlap near a corner. A later contact by a lower slot could
therefore steal a ball already inside a higher slot's catch circle.

A real match-scene regression failed at 30, 60 and 120 FPS: owner and touch credit
were slot 0 instead of slot 1 (200 passed, six failed). This proves a collision
ordering defect, not that it explains every campaign balance warning.

## Change

Source commit: `d854d69f2c8650a19bc426d2592b4d17aedfcea6`.

- Compute earliest segment/circle entry for every eligible active magnet.
- Select the earliest contact instead of the first roster entry.
- Resolve simultaneous entries with the match RNG; do not consume randomness
  for an uncontested capture. Replay/host authority retain the same seeded source.
- Preserve capture radius, attraction, timers, release speed, scoring and controls.

The focused suite passes 278 assertions: original network/physics/expiry cases,
first and reverse contact, stationary/outward travel, and reproducible simultaneous
contact across 64 seeds. An intermediate reverse fixture started too far away for
one 120 FPS step; corrected the fixture's start to cross the boundary in that step,
without changing the collision algorithm. Both failure logs are retained locally.

## Natural-match comparison

Each sample is 24 baseline matches, 16 paired difficulty matches and two stress
matches, all finishing naturally. Original reports remain in
`docs/qa/current-ball-balance-2026-10-08/`; changed reports are in
`docs/qa/magnet-swept-contact-2026-10-08/`.

| Offset | Before seat wins/bias | After seat wins/bias | Expert before/after |
| --- | --- | --- | --- |
| 1200000 | 6,12,4,2 / 0.25 | 6,11,5,2 / 0.208333 | 0.528846 / 0.528846 |
| 1500000 | 3,9,8,4 / 0.125 | 3,9,8,4 / 0.125 | 0.533654 / 0.533654 |

Both changed samples have no report flags, zero ties, and successful mutator/chaos
matches. Thresholds were not widened. Both use official Godot 4.7.1 and matching
start/end runtime fingerprint
`9661604bb8d963284bc45a54e27144ccce923fc2491140069a7315f0a516804f`.
Two small samples do not prove universal fairness or real-device performance.

## Verification and release gates

- Focused suite log: `/tmp/kras-magnet-capture-extended-final-engine.log`;
  existing strict test-log check passes.
- Natural logs: `/tmp/kras-magnet-contact-{1200000,1500000}-engine.log`;
  existing strict runtime-log checks pass.
- Full project gate passed (exit 0): 422 scripts compile, 522 resources with zero
  structural issues, 390616 assertions in 405.1 seconds, race regression, all six
  boss checks, and 39 stability matches with zero failures. Logs are under
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.PF93DI/`.
  The deliberately injected memory-warning test drained mesh/material/texture
  caches; its warning is expected and is not an actual device thermal test.
- Engine-log recheck: all eleven logs pass their appropriate modes (the test
  runner uses `tests`, the other ten also pass strict `import`). Applying `import`
  mode to the runtime test runner initially failed because it deliberately logs
  one blocked save write and three failed screen loads. Their stacks point to
  `test_save._failed_write` and `test_router_recovery`, which explicitly inject
  those faults and assert successful recovery. The logs were not edited, nor was
  the guard changed; this is not a claim that the test log contains no errors.
- Previous campaign reports and candidate 112 archive do not contain this runtime
  change. Requalify affected content and create a new exact-source local archive
  after release integration; do not relabel or reuse the old archive.
- No main merge, production Railway mutation, device performance sign-off,
  upload or App Review submission in this pass.
