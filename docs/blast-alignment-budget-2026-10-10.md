# Blast Ball alignment travel budget

Base: `a64063e` on `feature/kras-online-random-rotation`.
Candidate runtime fingerprint:
`96635c407c937275b23dec9a46e818342acb13b8f4a396c55e46cf65c70dd5eb`.
Checkout and isolated Godot copy match; both natural reports have matching
start/end fingerprints and official Godot 4.7.1.

## Defect and correction

Ball Brain reserves time to reach contact plus an escape window before an
offensive approach. When approaching from the side opposite a perceived rival,
it previously selected an alignment waypoint but budgeted only the shorter
direct distance to the ball. A marginal fuse could therefore fund the decision
without funding the selected alignment route.

The correction retains the initial eligibility/aggression check and the
existing delayed observations. If not already aligned, it additionally funds
travel to the chosen waypoint and the remaining distance from there to contact.
Already-aligned follow-through and direct approaches retain their previous
contact budget. No private ball momentum, opponent hidden state, difficulty
speed advantage, fuse extension or balance-threshold change was introduced.

Four rotated side-approach cases reproduce the defect: 397 assertions passed
and four failed before correction. After correction all 401 passed, including
the funded offensive control cases and prior fuse-age/status/escape checks.
All 449 scripts compile. Successful unit/compile logs pass strict guards.

## Natural-round qualification

Each post-fix cohort completed 96 baseline, 48 paired difficulty and two
mutator/chaos matches, 146 per cohort. Both logs passed strict guards and both
processes exited zero. Roster policy: `seeded_partition_seat_rotation`.

| Seed offset | Expert share | Character bias | Slot bias | Flags |
| --- | --- | --- | --- | --- |
| 0 before fix | 0.5041666667 | 0.0208333333 | 0.0104166667 | expert bots no better than easy |
| 0 after fix | 0.5458333333 | 0.0833333333 | 0.0416666667 | none |
| 8000000 after fix | 0.5270833333 | 0.0416666667 | 0.0833333333 | none |

Structured comparison verified identical offset-zero baseline seed/roster
arrays, round windows, difficulty pairing and difficulty seed/character/seat
configuration. A set comparison of baseline, difficulty and stress seeds
confirmed no overlap between the two post-fix cohorts: 292 new executions.

The before report belongs to c46a7f1, fingerprint 234b08ec. The intervening
runtime change besides this brain correction is Tank Arena's heading fix,
which is not used by Blast Ball. These results support this specific planning
repair; two passing samples are not all-game, all-arena or physical-device
balance acceptance. Earlier flagged campaign reports remain preserved.

## Evidence and outstanding gates

Logs and reports are retained at `../qualification-blast-alignment-2026-10-10/`.
No full CI on this candidate is claimed. Core `38017220130` and Tank network
`38017226293` still belong to d9c9c0a, before the Blast brain correction.
Do not cancel them or transfer their results to this candidate automatically.

Armed-race character balance, current-source all-game qualification, device
controls/performance/thermal checks, the remaining product features and
production authorization remain open. No stage DONE, game READY, main merge,
Railway deployment, release archive, Apple upload or review submission occurred.
