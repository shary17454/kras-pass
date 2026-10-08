# Rising Tide: intentional jump braking

## Defect and scope

The climber waits for horizontal speed below 0.25 before starting its jump
approach. Generic AI publishing added stick drift even when the climber
requested zero movement. On the actual floor, all four difficulty profiles
published nonzero movement during this deliberate stop. This can keep the
fighter moving instead of completing jump preparation.

The fix is confined to climber output: while grounded, preparing a known
elevated jump and intentionally requesting zero movement, publish zero movement.
Approach movement, ordinary drift, mistakes, reaction delay, visibility,
character physics, RNG, water speed, scoring and tie rules are unchanged.
Other action bits pass through unchanged.

## Regression evidence

- Before: tide_step_access, 136 passed, 4 failed; one failure per difficulty.
- After: 140 assertions passed, including physical ordinary jumping for all
  eight characters and climbing from four spawn positions.
- Climber delayed ground perception: 81 assertions passed.
- Compile check: all 424 scripts compile.
- The existing strict log guard passed all three positive checks.
- Full suite in a fresh isolated data directory: 392278 assertions passed in
  388.0 seconds, exit 0; strict test log guard passed, including resource leaks.

The first full run failed: 392274 passed, four replay assertions failed.
It reused an existing replay library: the idempotency fixture expected 41
entries even though the production retention limit is 40. Two byte-budget
fixture assertions also failed. This failed log is preserved, not discarded.
The follow-up full run uses a fresh `--test-data-dir` so unrelated retained
recordings cannot determine test expectations. No replay retention or runtime
storage logic was changed by this patch. Test-fixture isolation remains a
separate issue; a successful isolated run must not be described as repairing it.

The read-only `tests/tide_trace.tscn` diagnostic records positions, peak height,
grounded/alive state, the observed ledge plan and water level. It inherits the
natural simulation runner and does not inject input or alter results.

## Natural matches

Each sample contains 24 baseline matches, 16 matched-seed/character difficulty
comparisons and two mutator/chaos rounds, using official Godot 4.7.1 on macOS.

| Source/sample | Draw rate | Mean duration | Expert edge | Slot winner credits |
| --- | --- | --- | --- | --- |
| Parent, offset 2700000 | 10/24 | 10.704 s | 0.7200 | 9,12,8,9 |
| Fixed, same offset | 9/24 | 17.317 s | 0.7039 | 7,7,8,11 |
| Fixed, offset 2800000 | 7/24 | 16.563 s | 0.7102 | 9,8,8,8 |

Both fixed samples have no existing simulator flags and pass mutator/chaos
checks and strict log guards. This is not proof of complete balance: draws
remain frequent, and longer matches alone do not prove good climbing or fun.
Winner-credit totals include tied winners, not a one-winner-per-match count.
No warning threshold or result policy was relaxed.

Parent runtime fingerprint:
`ed4d18a506eacd11444c37d384019bdbd1be2a20ee07c56eb59c9934f62c5664`.
Fixed start/end fingerprints in both reports:
`7da82d6aadb77c695d3039ba4e6d7593f74574f97214e8c38e651a045cea3d78`.

Raw evidence is under `docs/qa/tide-jump-braking-2026-10-08/`.

## Historical all-game campaign

GitHub run 37734724695 completed successfully at source
`f2dcfd32b8cda63d68c3a9ea7a52958b6fda3840`.
All 39 downloaded reports were verified through `tools/balance-report.mjs`
with paired difficulty, offset 2700000 and source fingerprint
`39854bc0220d9911c43a4fce98c0d35dcc562dae73d196c9475c213c06d98e93`.
All 78 import/simulation logs passed the strict guard.
The summary verifies 1638 matches and preserves six balance reviews:
blast_ball, hurdle_dash, relic_hold, rising_tide, scrap_karts, sweeper_storm.

This is historical evidence, not qualification of the fixed source. Its
`releaseReady` remains false. Previous fixes require fresh current-source
campaign coverage; relic and sweeper character bias remain review items.

## Release status

No production deployment, main merge, latest-source iOS archive, upload or
App Review submission was performed by this change. Local Xcode 27 remains the
required archive path; the old candidate 112 does not contain this fix.
