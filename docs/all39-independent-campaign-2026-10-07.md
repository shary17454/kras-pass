# All-39 Natural Campaign Evidence

Campaign: https://github.com/shary17454/kras-pass/actions/runs/37526080082
Immutable source: d1a5a31f1d6af113e7c91dcdfa45acc68f2d41a9.
Seed offset: 300000. This older source does not qualify the later bridge,
island-routing, Blast Ball tie-selection or release integration changes.

## Verified Artifact Aggregation

All 39 game artifacts were downloaded to
/tmp/kras-campaign-37526080082-all39. Aggregation command:

```sh
node tools/balance-report.mjs /tmp/kras-campaign-37526080082-all39 \
  d1a5a31f1d6af113e7c91dcdfa45acc68f2d41a9 37526080082 \
  --paired --seed-offset=300000
```

Result: complete=true, gamesCompleted=39, gamesExpected=39,
matchesCompleted=1638, difficultyPairingVerified=true, missing=[].
Each game includes 24 baseline, 16 paired difficulty and two stress
matches. Completion is execution evidence, not a passing balance review.

## Retained Review Flags

| Game | Flag |
| --- | --- |
| blast_ball | expert bots no better than easy |
| crumble_court | expert bots no better than easy |
| gem_grab | expert bots no better than easy |
| scrap_karts | spawn slot advantage |
| sweeper_storm | expert bots no better than easy |

The aggregator explicitly reports balanceReviewComplete=false and
releaseReady=false. Do not suppress these flags or replace the campaign
with a more favourable seed. Later fixes require same-source verification
and independent seeds rather than inheriting this campaign's coverage.

## Next Gates

Investigate each flagged game's actual decisions and physics, preserving
perception limits and character fairness. Requalify the final integrated
source, then complete network/device/production/release checks. Neither
the campaign nor this report establishes an iPhone performance result,
production rollout, Distribution signing, App Store upload or submission.
