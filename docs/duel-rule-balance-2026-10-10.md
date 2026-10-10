# Duel Natural Balance After the Damage Correction

## Source and Scope

Tested commit: `6f5ba0e27693ea5eaf15f64ccec83f9e12b68d4a`.
Repository: `https://github.com/shary17454/kras-pass.git`.
Branch: `feature/kras-online-random-rotation`.
Godot 4.7.1 official, isolated imported runtime `/tmp/kras-tank-pursuit-check`.
Gameplay fingerprint, equal in checkout/runtime before and after both runs:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
Both reports record this same start/end fingerprint. This does not fingerprint
all assets, native builds, or physical-device behavior.

Two sequential campaigns used the unchanged balance harness, natural authored
duration, and supplementary seeded partition/seat-rotation rosters:

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-rule-fixed-80000000.engine \
  tools/balance_sim.tscn -- --runs=96 --only=duel_pit --balanced-rosters \
  --seed-offset=80000000 --out-dir=/tmp/kras-duel-rule-fixed-80000000-report \
  --test-data-dir=/tmp/kras-duel-rule-fixed-80000000-save
```

The held-out command uses `84000000` and corresponding
`kras-duel-rule-heldout-84000000` paths. No runtime, AI, character, rule,
geometry, harness, or acceptance-threshold changes occurred between campaigns.

Each completed 96 natural baseline matches, 48 matched/mirrored difficulty
comparisons, and two mutator/chaos instances: 146 each, 292 total. Both parents
returned exit 0 and all four stdout/engine guards passed. Report elapsed times
were 337.7 and 690.7 seconds, not phone FPS measurements. An observer timed out
while the second parent remained live; the same handle was retained and waited
to terminal completion without a replacement run.

Baseline seeds and rosters exactly match the corresponding pre-damage-correction
72ad reports. Both baseline seed sets contain 96 distinct values and have zero
overlap with each other. Every character appears 48 times in each sample.
Mirrored difficulty comparisons intentionally share their pair seed; the 292
instances are not claimed to have 292 distinct seeds.

## Results

| Metric | Independent 80000000 | Held-out 84000000 |
| --- | ---: | ---: |
| Mean natural duration | 61.8460069444422 s | 61.08784722222 s |
| Expert point share | 0.66 | 0.662 |
| Character bias | 0.0833333333333333 | 0.15625 |
| Seat bias | 0.0416666666666667 | 0.0208333333333333 |
| Sakhra wins | 15 / 96 | 27 / 96 |
| Sakhra before this rule correction | 21 / 96 | 27 / 96 |
| Ties / zero-score matches | 0 / 0 | 0 / 0 |
| Flags | none | character advantage |
| Mutator / chaos | both pass | both pass |

Seat wins: 28,18,24,26 and 26,24,26,20. Character wins:

| Character | Independent | Held-out |
| --- | ---: | ---: |
| Barq | 6 | 7 |
| Fanoos | 20 | 9 |
| Ghaim | 9 | 7 |
| Mowja | 9 | 4 |
| Nabta | 10 | 11 |
| Ramla | 7 | 9 |
| Sakhra | 15 | 27 |
| Turs | 20 | 22 |

The first flag-free sample does not settle balance. The held-out character
warning remains current, despite the independently proven correction of the
damage/life rule. Passing exit/log guards prove completed, structurally valid
experiments, not successful balance acceptance.

## Matchup Distribution and Next Experiment

The existing `seeded_partition_seat_rotation` sampler equalizes appearances
and seats, but does not equalize how often each pair of characters meets.
Sakhra's opponent counts illustrate this:

| Opponent | Independent | Held-out |
| --- | ---: | ---: |
| Turs | 32 | 8 |
| Mowja | 20 | 16 |
| Nabta | 16 | 20 |
| Ramla | 24 | 28 |
| Barq | 24 | 24 |
| Ghaim | 16 | 28 |
| Fanoos | 12 | 20 |

These counts are co-appearances, not head-to-head wins. Their difference is a
potential matchup confound, not proof that it causes the held-out warning or
that the gameplay is balanced. The existing sampler is retained as originally
documented; no warning or unfavorable report is discarded.

Next: add an explicitly supplementary eight-character pair-balanced diagnostic
schedule, including every pair equally and rotating all seats, with tests for
that invariant. Keep natural durations, the current gameplay, and existing
thresholds unchanged. Only then isolate combat resistance/power or geometry
if the character warning persists. Do not tune global stats merely to turn a
selected report green.

The current-source review index retains both reports, records both as eligible,
and keeps `requiresBalanceReview=true`, `requiresDeviceReview=true`, and
`releaseReady=false`. It is a review index, not canonical campaign attestation.

## Evidence and Gates

Raw JSON/HTML, original stdout/engine logs, and generated pair-count/review
metadata: `../qualification-duel-rule-balance-2026-10-10/`, outside Git.
Earlier failing regression and historical balance evidence remain preserved.
No code changes or new full-suite run occurred in this phase; the prior full
408391-assertion result belongs to the same gameplay source, as documented in
`duel-damage-contract-2026-10-10.md`.

This is Duel Pit on its default arena, four AI, not the current-source full
39-game campaign, other arenas, real humans/controllers, device performance,
production networking, or a signed-archive attestation. Stage 0 remains
QA_PENDING/MERGE_PENDING; later gated stages remain locked. No READY promotion,
main merge/push, Railway deploy/migration, new Archive, upload, or Apple review
submission occurred. Production backup/restore and device gates remain open.
