# Current ball balance evidence (2026-10-08)

## Source and scope

Campaign: https://github.com/shary17454/kras-pass/actions/runs/37694780646

Source commit: `82f3a7692b8f61b341fb26d69b3170c3a82496cd`.
The local held-out sample ran at `72398c390aef506dda5ac9d47f0296240e5baa32`;
its runtime source fingerprint is identical to the campaign reports:
`d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e`.
All five retained reports have matching start/end fingerprints and official
Godot `4.7.1-stable`. No gameplay, AI parameters, thresholds or scoring changed.

Each report contains 24 natural baseline matches, 16 matched-seed/character
difficulty comparisons, and two mutator/chaos matches. Baseline winners include
all eight rotating characters; the difficulty pairs exchange Expert seats.

## Results

| Game/sample | Seat wins | Seat bias | Expert edge | Flags |
| --- | --- | --- | --- | --- |
| Magnet, campaign 1200000 | 6, 12, 4, 2 | 0.25 | 0.528846 | spawn slot advantage |
| Magnet, held-out 1500000 | 3, 9, 8, 4 | 0.125 | 0.533654 | none |
| Storm, campaign 1200000 | 2, 7, 7, 8 | 0.083333 | 0.524038 | none |
| Sky, campaign 1200000 | 4, 10, 6, 4 | 0.166667 | 0.524038 | none |
| Blast, campaign 1200000 | 8, 4, 8, 4 | 0.083333 | 0.575 | none |

All samples have zero ties; both stress matches pass in each report. The second
Magnet sample does not erase the first warning or prove fairness. Both favor
seat 1 to different degrees. Determine a causal geometry/input/collision issue
before changing behavior; do not tune thresholds to hide this observation.

## Checks and current readiness

- Downloaded campaign source/checkout identity and all required seeds/coverage
  verified by `tools/balance-report.mjs --partial --paired --seed-offset=1200000`.
- Aggregate currently covers 10 of 39 games, 420 matches; warnings remain for
  Crumble Court and Magnet Court. Missing 29 campaign reports are not passes.
- Four new games' import, policy and simulation logs pass the existing strict
  `tools/check_godot_log.sh` checks. Held-out Magnet simulation also passes.
- Content audit using these ten reports plus the existing current-source Hurdle
  report: READY 0, NEEDS_POLISH 9, NEEDS_BALANCE 30, REWORK 0, BROKEN 0.
- `NEEDS_BALANCE` includes absent/stale evidence, not only demonstrated defects.
  Device portrait/landscape, sustained frame time/thermal and playability sign-off
  remain required. This is not an App Store release qualification.

## Evidence

Raw reports: `docs/qa/current-ball-balance-2026-10-08/`.
Downloaded artifacts: `/tmp/kras-current-partial-campaign-37694780646/`.
Held-out engine log: `/tmp/kras-magnet-heldout-1500000-engine.log`.
Content audit log: `/tmp/kras-current-ten-audit-engine.log`.
Generated audit: `build/party/content-audit.json` (ignored, not source).

No production Railway changes, main merge, native rebuild, upload or App Review
submission was performed by this evidence pass. The campaign remains in progress.
