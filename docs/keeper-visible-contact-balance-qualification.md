# Keeper Visible Contact Balance Qualification

## Verified campaign evidence

Downloaded artifact `natural-balance-goal_guard`, ID `11285396047`, from
GitHub run `37154262693`. Its source and checkout identify
`99d1b00d155d00c6faa372780fe26f5a152b8c6e`, natural mode, seed offset 100000,
24 baseline rounds, 16 matched difficulty comparisons and two stress rounds.

`summarizeBalance` from `tools/balance-report.mjs` was run on the downloaded
evidence with the exact commit, run, game, all eight character IDs and paired
difficulty required. It qualified 42 completed matches and their seed/character
provenance. This is a one-game qualification, not a complete 39-game campaign.

| Metric | Before: df4c67f | After: 99d1b00 |
| --- | --- | --- |
| Expert edge | 0.519230769230769 | 0.533653846153846 |
| Slot bias | 0.125 | 0.0833333333333333 |
| Character bias | 0.0416666666666667 | 0.166666666666667 |
| Slot wins | 5, 2, 8, 9 | 4, 8, 5, 7 |
| Tie rate | 0 | 0 |
| Flags | expert bots no better than easy | none |

Baseline seed lists and paired character comparisons match across both reports.
The geometric interception correction removes the prior warning in this sample,
but increases observed character variation. The small sample and threshold pass
do not establish universal balance or prove every character has equal strength.
The qualified summary deliberately retains `balanceReviewComplete=false` and
`releaseReady=false`.

Simulation/import logs contain no engine/script errors. The policy test log
reports 449 assertions passed and prints two intentional negative fixture
failures: `test_balance_sim.gd` explicitly checks that empty suites are rejected.
Those probe messages are not uncontrolled match failures.

Local artifacts:

- `/tmp/kras-goal-99d1b00-natural-evidence`.
- `/tmp/kras-goal-df4c67f-natural-evidence` for the matched prior sample.

The deployed e1c5e34 commit includes 99d1b00, and a Git diff of src, tests,
project.godot, data and scenes between those commits is empty. This validates
that game-code comparison only; it does not claim every infrastructure file or
the complete tree is identical. Full current-main CI, all-game balance review and
physical-device QA remain separate gates before App Store submission.
