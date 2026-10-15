# Keeper terminal goal boundary

Parent: `80d4c5a3a8163b8eb925dbf791bbc6083474d802`.
Branch: `feature/kras-online-random-rotation`.

## Defect and fix

GitHub balance run 37877408528, source
`ba2ada7c10ce0916f8d499895ff9164380c97150`, failed storm_heart with two
zero-score rounds at seed offset 5400000. The original completed artifact is
retained at `/tmp/kras-ba2-storm-failed-ci/`; its failure is not overwritten.

Goal Guard checks its terminal condition after controller.tick. Within that
tick, a later ball could concede the last survivor's point after an earlier
ball had already left exactly one keeper with points. This violates the
existing last-keeper win condition and turns a decided round into all zeroes.

`_on_goal` now returns when the existing `is_round_over()` condition is met.
No scores are fabricated; no balance thresholds, ball tuning, AI parameters,
protocol schema or results ranking changed. Subsequent goal callbacks cannot
eliminate the winner, add conceded events or relaunch a ball.

## Regression evidence

Tests cover Goal Guard and Storm Heart, rosters of 2, 3 and 4, every ordered
pair of final contenders (40 cases). The penultimate concession ends the
round; a subsequent goal must preserve the survivor's point and state.

- Before fix: 184 assertions passed, 160 failed; exit 1.
- After fix: Goal Guard suite 344 assertions passed; exit 0.
- Storm network/replica suite: 178 assertions passed; exit 0.
- All 440 scripts compile; exit 0.
- Strict runtime log guards passed for all final local test logs below.

## Natural campaign verification

Each campaign contains 24 baseline, 16 paired difficulty and two mutator
smoke matches; default natural-round policy and 60 fixed simulation steps.

| Game | Seed offset | Zero-score rounds | Ties | Expert share | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| Storm Heart | 5400000 | 0 | 0 | 0.533654 | none |
| Storm Heart | 5200000 | 0 | 0 | 0.519231 | expert bots no better than easy |
| Goal Guard | 5400000 | 0 | 0 | 0.528846 | none |

The independent Storm Heart campaign still fails the separate expert-tier
balance threshold (0.52). Do not call Storm Heart fully balanced or READY.
The end-of-round defect is fixed; difficulty balance remains an open issue.

## Real multi-engine verification

`node network-smoke.js --game=storm_heart --humans=4`: exit 0, PASS.
Four actual Godot peers agreed on aggregate scores `[15,15,16,9]`.
Host and one guest reconnected. Guests received 1088-1107 world snapshots.
Server loop maximum 52 ms; not a production latency acceptance result.
All four raw peer logs passed strict runtime guards.
No production service was used or changed.

## Evidence and limits

Local logs:
`/tmp/kras-terminal-keeper-red.stdout`,
`/tmp/kras-terminal-keeper-green.stdout`,
`/tmp/kras-terminal-storm-network.stdout`,
`/tmp/kras-terminal-keeper-compile.stdout`,
`/tmp/kras-terminal-storm-campaign.stdout`,
`/tmp/kras-terminal-storm-independent.stdout`,
`/tmp/kras-terminal-goal-campaign.stdout`,
`/tmp/kras-terminal-storm-four-peer.stdout`.
Campaign JSON reports are under corresponding `/tmp/kras-terminal-*/`
output directories. Original peer logs:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-SSIeiT/`.

Full regression, the complete 39-game remote matrix on this new source,
remaining AI balance, projectile-render stalls, physical iPhone qualification,
production migration/deployment and a fresh local Xcode 27 archive remain
required. No main merge, Apple upload, review submission or withdrawal occurred.
