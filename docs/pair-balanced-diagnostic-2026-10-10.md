# Pair-balanced Duel diagnostic - 2026-10-10

## Scope and source

This phase adds development-only sampling fixtures. It does not change character
stats, AI, physics, arenas, Duel rules, production services or acceptance limits.
The existing canonical sampler remains unchanged. Stage 0 remains QA_PENDING /
MERGE_PENDING; later product stages remain locked.

Source parent: `53a16e844b5cdcd263dffe524de1deb06bd85ecd`, on
`feature/kras-online-random-rotation`, plus the five test files recorded below.
Godot: `4.7.1-stable (official)`, headless, fixed physics FPS 60. This is not an
iPhone rendering, battery, heat or physical-controller qualification.

Gameplay fingerprint, identical before/after and between checkout/runtime:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
This fingerprint excludes tests, most assets and native release outputs.
The five fixture hashes are separately attested in `source-before.json` and
`source-after.json`; every runtime fixture is byte-identical to the checkout.
No fixture or gameplay edit occurred while a campaign was running.

## Diagnostic design

`tests/balance_pair_schedule.gd` rotates the 14 affine planes over eight labels
through four seats. Each 56-match cycle gives every character 28 appearances,
seven in each seat, and every pair 12 co-appearances. Labels are seeded locally;
the global gameplay RNG is not changed. Invalid catalogs and incomplete cycles
are rejected. The driver inherits the existing real MatchScene harness.

The actual 112-match report was audited independently, not just inferred from
the schedule: every character appears 56 times, 14 in each seat, and each pair
24 times. Each cycle contains 14 distinct quartets, each repeated four times.
All 112 baseline seeds are unique. Co-appearance equality does not prove equal
teammate/opponent roles in team games; this sample is Duel free-for-all only.

Reproduction:

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-pair-88000000.engine \
  tests/balance_pair_sim.tscn -- --runs=112 --only=duel_pit \
  --seed-offset=88000000 --out-dir=/tmp/kras-duel-pair-88000000-report \
  --test-data-dir=/tmp/kras-duel-pair-88000000-save
```

## Results

- Natural baseline: 112/112 completed.
- Matched, mirrored difficulty comparisons: 56/56 completed.
- Mutator/chaos smoke: two instances; 170 total instances, not 162.
- Campaign terminal exit: 0; elapsed 549.7 seconds.
- Mean simulated round duration: 60.958 seconds.
- Expert point share: 0.6537815.
- Character bias and seat bias: both 0.0803571; report flags empty.
- Wins: Barq 12, Fanoos 13, Ghaim 13, Mowja 13, Nabta 9, Ramla 13,
  Sakhra 23, Turs 16. Seat wins: 37, 24, 25, 26.
- Ties: zero; zero-score baselines: zero.

The fixed fixture suite passes 1,766 assertions. Compile qualification passes
455 scripts. A fresh full suite passes 410,156 assertions in 811.5 seconds,
terminal exit 0. Both stdout and engine logs pass the strict checker for the
fixture suite, compile, full suite and actual balance campaign: eight logs.
`git diff --check` also passes before documentation changes.

The first targeted fixture attempt failed with a missing indentation in the
new test, before any qualifying campaign. It was corrected, rerun successfully,
and its failed raw logs remain available; they were not replaced or relabeled.

## Warning history and acceptance

The post-rule held-out sample at seed offset 84000000 still reports
`character advantage` (Sakhra 27/96). The new flag-free sample does not erase it,
prove the earlier warning's cause, or approve character balance. The three-report
review index retains that warning with `requiresBalanceReview=true`,
`requiresDeviceReview=true` and `releaseReady=false`.

Next: independently replicate the pair-balanced diagnostic before considering
any character tuning. Preserve the canonical sampler and old warnings. This is
supplementary evidence, not qualification of all 39 games or a release archive.

## Evidence and release gates

Raw evidence is outside Git at `../qualification-pair-schedule-2026-10-10/`:
`report.json`, `report.html`, `roster-audit.json`, `sample-review.json`, source
attestations, initial/fixed fixture logs, compile logs, full-suite logs and
campaign logs. Copies were compared with their original bytes.

Changes: four new diagnostic/test files and registration in `test_runner.gd`.
No gameplay breaking change or new production migration is introduced.
The local checkpoint uses `Update project`; no merge or push to main is claimed.
Main promotion remains blocked by the production backup/restore approval gate.
Railway synchronization, current local Xcode archive, device QA, upload,
processing and App Review submission are not completed by this phase.
