# Sweeper quarter resistance response

Parent checkout: `15544a2`, branch `feature/kras-online-random-rotation`.
This is a scoped balance improvement, not complete product/release acceptance.

## Change

Sweeper Storm now uses `resistance_influence=0.25`, instead of 0.5. Only the
mode-local rotating-arm impact response changes. Existing response math retains
the character resistance ratio raised to the configured influence. Heavy
characters still receive less push; neutral strength stays unchanged.

Character stats, perks, combat mass, rival attacks, vehicle integration, other
games' hazards, jump physics, AI perception, timers, scoring, and acceptance
thresholds are unchanged. The development neutral-resistance experiment is not
the shipped behavior. It was rejected because its difficulty warning remained.

## Natural comparisons

All runs use authored natural rounds, balanced seeded rosters, 96 baseline
matches, 48 matched character/seed difficulty matches, and two mutator matches.
Each report completed all 146 matches with stable source fingerprints and a
clean runtime log. Baseline roster and difficulty pairing arrays matched in
both comparisons.

| Metric | Baseline 13100000 | Candidate 13100000 | Baseline 14700000 | Candidate 14700000 |
|---|---:|---:|---:|---:|
| Sakhra wins / 96 | 27 | 18 | 25 | 14 |
| Character bias | 0.15625 | 0.0625 | 0.135417 | 0.0520833 |
| Slot bias | 0.0729167 | 0.0208333 | 0.0625 | 0.0416667 |
| Expert point share | 0.540541 | 0.534161 | 0.580579 | 0.578512 |
| Mean simulated seconds | 31.2036 | 28.6953 | 27.7802 | 27.7490 |
| Flags | character advantage | none | character advantage | none |

The first baseline is retained from the prior unchanged gameplay source at
9b88f56; the independent baseline was run on the current parent runtime.
The source fingerprint differs only because localization descriptions changed.
This turn completed three new 146-match campaigns (438 matches); with the
retained first baseline, the comparison covers 584 matches, not 584 new runs.
The held-out cohort was evaluated after selecting the candidate.

Fingerprints:

- Retained baseline: `87864f3ec75cfa8f3722f5001cf9372d7872bc589c83e632889131af1c29377a`
- Current independent baseline: `ac53d83e830554ed48e52f1d404104f8c9d3f20117e91eb0a4bff421e3abc063`
- Both candidate cohorts: `2bcfc4b9d2af0f5d7aac6829a8788c7876e26a9ab3e264722489bd00a6bf12ee`

Before adoption, a structured comparison confirmed that only this tuning value
differed; the other 546 tracked runtime/content/tool files were identical.
Final candidate tuning and updated tests match the tested temporary project.

## Focused checks

- Real physical impact/response suite: 108 assertions passed, covering all eight
  characters, both 0.25 and 0.5 response values, neutral strength, clamps, and
  unchanged combat resistance.
- Network presentation suite initially failed three assertions that explicitly
  expected the old authored 0.5 setting. The intended expectation was updated
  to 0.25; final suite passed all 29 assertions. Packet validation and client
  presentation authority checks were not weakened. Both logs are retained.
- Compilation: all 448 scripts passed.
- Strict test/runtime log checks passed for the final tests, compile, and all
  completed natural reports. The initial network expectation failure remains
  recorded, not treated as a successful test.
- Full Core regression on the new commit remains pending; the older green Core
  run on 9b88f56 does not qualify this gameplay change.

## Evidence And Gates

Raw reports and logs: `../qualification-sweeper-quarter-2026-10-10/`.
Local temporary candidate: `/tmp/kras-tank-pursuit-check`.

Existing all-39 campaign `37997079439` remains on frozen source 9b88f56. It was
not cancelled or replaced, and cannot automatically qualify the new tuning.
These two cohorts do not prove universal balance or human playability.
Stage 0 QA/MERGE remains open, as do device, production, and release gates.
No main promotion, Railway deployment, archive, upload, or submission is included.
