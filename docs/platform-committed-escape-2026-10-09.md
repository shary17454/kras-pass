# Platform escape direction qualification

Parent commit: `1e89b5401b624e3608ff77d8abc45d207bc46d39`.
Branch: `feature/kras-online-random-rotation`. Godot: 4.7.1.

## Runtime change

`platform_brain.gd` previously rerolled its walking route whenever the origin
was unsafe, with probability `edge_awareness` per ordinary decision. Two equally
safe destinations could therefore reverse escape input before either was reached.
Keep a committed, visible, solid first step instead. Replan when it disappears,
starts falling/shaking, or is no longer adjacent to the bot's current observed
support after displacement. Existing jump reaction delays and visible-route
selection remain in use. No character stats, movement speed, jump impulse,
collision shapes, difficulty profiles, scoring or warning timings changed.

## Red-to-green evidence

- Initial regression: 2,239 assertions passed, 138 failed. It reproduces route
  reversal across 128 independent seeds with two equally safe exits.
- Initial retention fix: 2,377 passed. A further displacement regression then
  failed (2,377 passed, one failed), exposing a stale remote first step.
- Final regression: 2,378 passed, including displacement, hidden/collapsing
  targets, reaction delay, equal-route fairness and native floor/arrival fixtures.
- Final full regression: 396,779 passed in 219.8 seconds, engine exit zero and
  positive completed-summary log guard passed.
- Final compile check: 442 scripts compile, engine exit zero and log guard passed.

## Matched natural-round campaign

Before and final after reports use the same baseline seeds and the same
`seed`, `character`, `expert_slots` tuples in all difficulty samples (compared
as structured JSON). Each completed 120 baseline games, 60 mirrored difficulty
comparisons and two mutator/chaos smoke games. No duration clipping was introduced.
All report source fingerprints remained identical from start to end of each run.

| Metric | Before | Final after |
| --- | --- | --- |
| Slot wins | 22, 37, 24, 37 | 27, 33, 26, 34 |
| Expert share of placement points | 55.83% | 54.00% |
| Ties | 0 | 0 |
| Average baseline duration | 13.196 seconds | 13.584 seconds |
| Report flags | none | none |
| Mutator / chaos smoke | passed / passed | passed / passed |

Before fingerprint:
`cf83a6babd8d2984c5b54f6a63bb9d99edf7627b5136f039054fcdf93f6adf3e`.
Final after fingerprint:
`12534d79685ad156d361ef5141107aa54670d5744e8bd4e163cde0cb3dbb8b7a`.
An intermediate source is retained separately, not substituted for final evidence.
Expert separation decreased, so this is not a claim of improved difficulty balance.
The older small campaign's weak-Expert flag did not reproduce even before this fix.
No flag thresholds were relaxed and no difficulties weakened to hide a warning.

## Evidence and limits

Raw reports and logs are retained outside the checkout in
`../qualification-platform-escape-2026-10-09/`:
`before-report.json`, `intermediate-report.json`, `after-report.json`, red/green
suite logs, `kras-crumble-displaced.stdout`, compile and final full-regression logs.

This is one game's route stability fix, not qualification of every game/map or
proof of iPhone frame pacing, energy use, human multiplayer or production online.
Other balance flags still need review; CI/network campaigns on older commits do
not attest this new runtime. No main merge, production account migration,
Railway deployment, native archive, App Store upload or review submission occurred.
