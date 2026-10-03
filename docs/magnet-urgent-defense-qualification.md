# Magnet Court urgent visible-ball defense

## Change and boundaries

Source: `b3d3b64505f4c9bf4abd8e23fd17bbb67ec38202`, based on
`d177bb41c5c51f05377861c97516c8899d4e62db`.

Higher-strategy bots previously waited for two incoming balls even when a
single fast ball was about to reach them. The magnet now also activates when
delayed observed motion predicts closest approach within half the magnet's
active duration and inside its catch radius. The existing readiness check,
multi-ball strategy, reaction delay, observation filter and movement remain.
No private ball velocity, hidden-ball position, extra speed or score bonus is
used. Geometry constants come from the actual Magnet Court controller.

## Regression evidence

- Same final visibility suite on the previous magnet decision: 131 passed,
  4 failed (urgent single-ball saves in all four directions), exit 1.
- New decision: 135 visibility assertions passed, exit 0. Departing balls,
  slow arrivals, passing trajectories outside catch radius, hidden balls,
  empty charge and missing observations do not trigger emergency activation.
- Magnet mechanics/network authority: 190 assertions passed, exit 0.
- Goal Guard shared keeper: 144 assertions passed, exit 0.
- All 324 Godot scripts compile; `git diff --check` passes.

Runtime source: `/tmp/kras-cloud-export-uid-check`, mirrored from the publishing
checkout. Baseline: `/tmp/kras-keeper-baseline-check`, retaining the previous
magnet script and using the same final regression fixture. The baseline's older
keeper does not determine the emergency probe: that probe overrides keeper
target selection and supplies observed ball history explicitly.

Logs: `/tmp/kras-magnet-deadline-baseline.log`,
`/tmp/kras-magnet-deadline-test.log`, `/tmp/kras-magnet-urgent-network.log`,
`/tmp/kras-magnet-urgent-goal.log`, `/tmp/kras-magnet-urgent-compile.log`.

The first sandbox launch failed to create its user log and crashed before
testing. Local execution with authorized system access succeeded. An initial
test variable collided with Node's `ready` signal; it was corrected before the
reported baseline/final runs. The short suite name `magnet` selected no tests;
the reported 190 assertions are from the actual `magnet_network` suite.

## Natural-round sample

`magnet-urgent-defense-balance.json` retains the complete generated report.
24 natural matches, 16 matched seed/character difficulty samples with mirrored
Expert slots, and 2 mutator/chaos matches all completed (42 total), exit 0.
Difficulty rank-point share improved from 0.509615384615385 in the keeper-only
candidate to 0.524038461538462. Flags are empty; ties are zero; both mutator
checks pass. This is a small fixed-seed sample, not a win rate, population
confidence estimate or proof that all characters/games are balanced.

## Release gates still open

No automatic merge, signed archive, production multiplayer activation, App
Store upload or review submission follows from these targeted tests. Current
source-wide CI, wider independent balance samples, the other campaign review
flags, physical iPhone/iPad QA and the final release-source/signing/production
checks remain necessary.

Historical network run 37113428591 completed successfully with 40 jobs, but
uses earlier source and does not qualify this change. Run 37120360085 remains
live at the last check (18 successful jobs, zero failed). Main source d177bb4
has its own run 37123008553, observed queued; these are separate evidence.
