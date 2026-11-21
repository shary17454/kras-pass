# Current Scrap balance diagnosis

Tested source: `b3ec09a0546dcb50217897e40b8fd254c008ff69`.
Runtime and rules were unchanged throughout these measurements.

## Reproducible observations

The existing read-only tactics tracer completed sixteen natural paired
matches. Independently checked sample index, seed, character, scores, places
and natural completion match the existing current-source 1200000 report
exactly. This is additional observation of those sixteen configurations, not
sixteen new independent seeds or a gameplay fix.

| Tier | Participations | Ram exits | Falls | Survivors | Alive ticks | Backoff ticks | Edge ticks | Dash ticks |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Easy | 32 | 25 | 0 | 7 | 45601 | 4547 | 8450 | 446 |
| Expert | 32 | 24 | 0 | 8 | 42349 | 14911 | 6459 | 1813 |

No fall explains this cohort's Expert warning. More backoff and dash exposure
are hypotheses, not established causal defects. Earlier facing-backoff and
ram-alignment tactics remain rejected; their unfavorable independent results
must not be discarded or those changes reintroduced without new evidence.

## Independent and expanded natural samples

| Offset | Baseline | Mirrored difficulty | Stress | Expert share | Seat wins | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 1200000, prior current report | 24 | 16 | 2 | 0.506250 | 4,10,5,5 | Expert no better than Easy |
| 1500000, new held-out | 24 | 16 | 2 | 0.602484 | 6,7,5,6 | none |
| 1200000, expanded | 96 | 48 | 2 | 0.537344 | 35,22,17,22 | spawn slot advantage |

The expanded report contains the first sample's configurations. It must not be
added to that first report as if every observation were independent. The new
42-match held-out sample and 146-match expanded sample completed naturally;
all eight characters recur in the mirrored comparisons. Independent Node
validation checked every seed, character, mirror, completion, ranking and
recomputed the Expert share from places. Both mutation checks passed in each
report. Strict engine log guards passed for trace and both simulations.

Official Godot 4.7.1 start/end fingerprint in both new reports is
`ef891f443408c595f6440a9e3d5d4dec8dc41fb1008be8e05894cf92e94ac524`.
No AI profile, physics value, acceptance threshold, character stat, seed
selection or balance-policy change was made. The larger sample reveals a seat
warning; it is not a reason to mark Scrap READY. Next investigate simultaneous
contact resolution and roster-order dependence separately from AI tactics.

## Evidence and remaining gates

- Raw reports and trace: `docs/qa/scrap-current-diagnosis-2026-10-08/`.
- Trace log: `/tmp/kras-scrap-current-tactics-2026-10-08-engine.log`.
- Held-out log: `/tmp/kras-scrap-current-heldout-1500000-engine.log`.
- Expanded log: `/tmp/kras-scrap-current-expanded-1200000-engine.log`.
- Expanded run: exit zero, 193.1 seconds. Held-out: exit zero, 34.5 seconds.

The existing campaign validator verified the selected held-out game and
reported 1/39 games, 38 missing, `complete=false` and `releaseReady=false`.
The expanded sample uses its declared larger counts, not fake 24-run campaign
metadata. This evidence does not complete the all-game campaign, production
qualification, physical-device performance or Apple release. No main merge,
production operation, archive or Apple action occurred.
