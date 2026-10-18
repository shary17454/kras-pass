# Meaningful Leader Targeting: Qualified Repair, Balance Still Open

Runtime/test commit: `dec8041220d34fd8ec43f81e6d2596bdaacd8feb`.
Branch: `fix/kras-meaningful-leader-target`, based on survivor winner repair.

## Reproduced Policy Error

`priority_rival()` blended nearest targeting with a randomized co-leader even
when the nearest opponent had exactly the same score. Scrap Karts running
scores stay tied: results are computed at round end. Thus a distant rival could
replace a nearby engagement without any meaningful score lead.

Real four-player Scrap context, all four tiers: RED 525 pass / 636 fail, exit 1
(`/tmp/kras-leader-red.stdout`). GREEN 1161 assertions / strict guard 0
(`/tmp/kras-leader-green.stdout`). Cases include tied zero/positive/negative
scores, nearest co-leader, actual higher-scoring visible leader, hidden or
eliminated leaders, and no target before perception becomes actionable.
Selection cases use a zero-delay fixture to isolate targeting; production AI
profiles, reaction delays, visibility, character stats and physics are unchanged.

When the chosen leader has no score advantage over the nearest eligible rival,
the policy now returns that nearest rival. Actual score leaders still attract
strategic targeting through the original strategy/gap blend. `leader_rival()`
tie randomization and all visibility/reaction guards are unchanged. The policy
changes decision RNG consumption when this early-return applies; natural
comparisons qualify the complete candidate, not an isolated RNG-free model.

Existing AI visibility/reacquisition tests: 4069 pass / strict guard 0
(`/tmp/kras-leader-visibility.stdout`).

## Full Regression

`GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`:
`/tmp/kras-party-check.YuoxCI`, overall exit 0, every strict log guard passed.

- 419 scripts compile; 518-resource inventory, 22 autoloads, 27 routes,
  eight characters, zero issues.
- 389884 unit/integration assertions pass in 345.5 seconds.
- Actual three-lap race, six explicit defeated-boss checks and 39 stability
  matches pass, zero stability failures.
- Settled caches return to zero. This single headless cycle is not long-soak,
  native-renderer, phone FPS, heat, battery or gamepad/touch qualification.

Server with six fresh engine captures from YuoxCI: 204 pass, zero fail/skip,
exit 0, 751.2 ms (`/tmp/kras-leader-server-tests.log`). Approved loopback-only
execution, no production DB/accounts. npm audit reports zero known dependency
advisories (`/tmp/kras-leader-npm-audit.json`), not full security certification.
Known macOS CA diagnostics and intentional save/router/memory-warning fixtures
remain visible. No test, threshold or log guard was weakened.

## Natural Comparisons and Held-out Failure

Each current-source row comprises 24 baseline rounds, 16 matched-seed and
matched-character difficulty rounds, and two short smoke rounds. Independent
Node verification confirms all counts, seeds and eight mirrored character
pairs. The smoke checks do not establish natural-duration balance. All strict
runtime guards pass. Current 272-file fingerprint:
`e18fa8c14dc94cc4d57b7764e728807f88b13875835118a22da31466ed8df165`.
All four reports have identical source-start/source-end fingerprints.

| Game / offset | Expert share | Character bias | Slot bias | Flags |
| --- | --- | --- | --- | --- |
| Scrap / 1200000 | 0.525 | 0.125 | 0.2083333 | none |
| Scrap / 1500000 | 0.54375 | 0.2083333 | 0.0833333 | none |
| Scrap / 1800000 | 0.51875 | 0.0833333 | 0.0416667 | Expert no better than Easy |
| Ring Rumble / 1200000 | 0.5625 | 0.1666667 | 0.2083333 | none |

All tie rates are zero. First two Scrap samples improve over parent shares
0.49375/0.5125, but the first remains close to the existing 0.52 warning cutoff.
Held-out seeds were not used in those previous comparisons and retain a warning.

Same held-out 42-match run on clean parent
`42c852dcb870cf44daac407a770b41e78d2f6564` (runtime e07a540) has Expert share
0.50625 and the same warning, fingerprint
`bb391fb77305db702f2ecc5438de81703adfab4859fc0cf4e3c5a4056de9f290`.
Pair/count/seed and log guards passed. The candidate modestly improves that
sample too, but does NOT resolve overall difficulty balance. Total inspected:
168 candidate matches plus 42 parent comparison matches.

Raw reports and paired validation are committed alongside this document:
`meaningful-leader-scrap-natural-{1200000,1500000,1800000}.json`,
`meaningful-leader-ring-natural-1200000.json`,
`meaningful-leader-parent-scrap-natural-1800000.json`, and
`meaningful-leader-paired-validation.json`. Preserve parent warnings/reports.
`balanceReviewComplete=false` and `releaseReady=false` remain unchanged.

## Remaining Scope

Shared consumers include driver, tank, gunner, bomber and generic arena AI.
This turn does not provide current-source natural balance for every consumer,
all 39 games, all maps or native humans/gamepads. Do not infer those gates from
two tested games or a successful regression/stability cycle.

Existing remote campaign 37616445234 was read, not restarted/cancelled: 25 jobs
completed, overall queued at the latest query. It runs an older source and is
not candidate qualification.

No main merge, protected database action, Railway rollout, phone replacement,
new archive, Apple upload or submission. Complete balance/polish, current native
device and production acceptance, then freeze a new release commit and use local
Xcode 27 Distribution signing. Existing archives predate this repair.

## GitHub Delivery Status

The branch was pushed and its remote SHA verified. Draft PR creation did not
succeed: two GraphQL attempts returned GitHub internal execution errors
(2026-10-07 15:07:25/15:08:18 UTC); a REST attempt returned an empty/unparseable
response. Read-only REST checks after these unknown outcomes returned no PR
for this head. Do not claim a PR exists or blindly create duplicates. No merge
or branch protection override occurred. The prepared PR body is preserved at
`/tmp/kras-leader-pr-body.md` for a later verified retry.
