# Shared Vehicle Movement: Natural Follow-up

Source tested: `0fccdd68aafc3298aabe327a09a27a6ef331e44a`.
Runtime remains `200324543fcd18ad10e5b3a3161c6aff9d09bf82`; intervening changes
are evidence documentation only. No runtime, thresholds or AI parameters were
changed during these runs.

All three current-source reports have unchanged start/end fingerprint
`9e589f977babb4ef14a773bfd0c172cab21ab63252453c59e2d5180a84eedb5c`.
Each completed 24 natural baseline rounds, 16 seed/character-matched mirrored
difficulty rounds and two short mutator/chaos smoke checks. The existing report
validator confirmed completion, seed identities and all eight character pairs.
Each process exited 0 and passed the strict Godot log guard. Exit 0 is NOT a
balance acceptance: severity-1 balance warnings do not make that process fail.

| Game | Seed offset | Expert placement share | Character bias | Slot bias | Ties | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| Tank Arena | 1200000 | 0.58125 | 0.166667 | 0.041667 | 0 | none |
| Scrap Karts | 1200000 | 0.5375 | 0.083333 | 0.083333 | 0 | none |
| Scrap Karts | 1500000 | 0.425 | 0.166667 | 0.125 | 0 | expert bots no better than easy |

These are samples, not universal character equality or actual human/device QA.
In particular, Scrap Karts' first marginal pass cannot override its second
sample's retained difficulty failure. Tank Arena's single successful sample
does not certify every arena, projectile variant or the separate Turret Duel.

## Same-seed Parent Comparison

A fresh run on clean parent `155fabe41431d2846fb798b70ce7e1cf5fc68054`
with offset 1500000 also completed all 42 requested checks, exit 0/log guard 0.
Its unchanged fingerprint is
`096a5e758d0301d1d324340147e285d9e3133c887482ebcdd1bd820f0d322a01`.
It retained the same warning, Expert share 0.49375, character bias 0.125,
slot bias 0.041667 and zero ties.

Thus the difficulty weakness predates the speed-budget change, while this
same-seed sample is worse after that change. Neither the pre-existing warning
nor passing Rocket Rally samples justify accepting a regression in the shared
vehicle family. The speed-budget PR remains draft, not a main/release merge.
Next work must investigate the driver agent's engagement/backoff/edge handling
and qualify its behavior without privileged perception or hidden stat buffs.
Do not lower the acceptance threshold or discard offset 1500000.

## Preserved Reports

- `vehicle-speed-tank-natural-1200000.json`
- `vehicle-speed-scrap-natural-1200000.json`
- `vehicle-speed-scrap-natural-1500000.json`
- `visible-target-scrap-natural-1500000.json` (parent comparison)

Logs use corresponding `/tmp/kras-vehicle-speed-{tank,scrap}-natural-*.stdout`
and `/tmp/kras-visible-target-scrap-natural-1500000.stdout` paths. Raw JSONs
retain complete difficulty samples, seeds, win counts and smoke outcomes.

## Existing CI Campaign, Not Current-source Qualification

Read-only inspection of campaign 37616445234 found 16 completed jobs and no
failed jobs at inspection; the campaign itself remained queued/incomplete.
Fifteen game artifacts downloaded successfully. The existing validator checked
630 matches, with 24 games still missing and one Scrap Karts difficulty warning
(Expert share 0.50617284). Summary: `campaign-37616445234-partial15.json`.

That campaign's source is
`96c53f359cbb48663a9a99d3fec5ecf6e16d16af`, not the current vehicle source.
Its partial reports therefore inform follow-up priority, not current-source
release acceptance. The validator preserves `complete=false`,
`balanceReviewComplete=false` and `releaseReady=false`.

No main merge, production database action, Railway rollout, device app
replacement, archive, upload or Apple review submission occurred. Current-source
Kart Sprint/Turret Duel natural qualification, resolved Scrap Karts difficulty,
native 1-4-human/controller/performance QA and production/release gates remain.
