# Replay Retention and Production Qualification

## Exact Source

Runtime source: `01c5362dea176e86223548cacaec0332150e4323`.
Repository: `shary17454/kras-pass`; production branch: `main`.
The source was fast-forwarded and pushed without rewriting shared history.
This document is evidence qualification, not an App Store release approval.

## Corrected Behavior

With forty highlighted recordings, pruning previously deleted a newly saved
ordinary replay and still reported success. Interrupted-save recovery had the
same problem: its recovery count included a recording immediately removed.

The newest saved or recovered replay now receives protection for that pruning
pass only. Older ordinary recordings remain eligible for eviction; when all
other recordings have highlights, the oldest eligible highlight is evicted.
The forty-recording, 64 MiB individual-file and 256 MiB library limits remain
unchanged. Recovery reports only newly recovered recordings actually retained.
Protection does not bypass an impossible byte budget or cause an infinite loop.

## Reproduction and Regression Evidence

- `/tmp/kras-replay-retention-behavior-before.log`: 44 assertions passed,
  five failed against the previous save implementation. Newly saved file,
  index entry and readable replay were lost. An earlier test setup had a
  signature parse failure; that was not behavioral reproduction evidence.
- `/tmp/kras-replay-recovery-retention-before.log`: 56 passed, three failed
  against the old recovery implementation after fixing save retention.
- `/tmp/kras-replay-retention-final.log`: all 63 assertions passed, including
  newest orphan recovery, pruning an older orphan, accurate recovery count,
  actual readable files, bounded count, byte limits and impossible-budget exit.
- `/tmp/kras-replay-storage-retention-regression.log`: all 33 assertions passed.
  Deliberate blocked-write and oversize fixtures emit expected warnings.

## Integrated Runtime Checks

Godot: 4.7.1 official `a13da4feb`.
`tools/check_party.sh` exited zero on the exact runtime source above.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.SLdCB0`.

- 371 scripts compiled.
- Inventory: 411 resources, 21 autoloads, 27 routes, eight characters,
  zero inventory issues.
- Full test runner: 360123 assertions passed, 225.6 seconds.
- Race regression and six authored boss probes passed.
- One stability cycle: all 39 matches completed, zero failures.
- No successful `saved replay ... 0.0 KB` entry was found in this run's
  `tests.log`; this is a run-specific observation, not a universal guarantee.
- Fresh server tests used all six world captures from this evidence directory:
  192 passed, zero failed, zero skipped. Log:
  `/tmp/kras-replay-retention-server-captures.log`.

## Natural Ring Rumble Sample

`/tmp/kras-ring-natural-01c5362/report.json` records 24 natural baseline
matches, 16 matched-seed/character difficulty samples and two mutator/chaos
smokes. All completed. Mean baseline duration: 41.8549 seconds;
tie rate: zero; slot bias: 0.125; character bias: 0.1667.
The expert place-share metric is 0.56875, not a win rate.
The tool reported no flags for this sample. This small sample neither proves
balance for Ring Rumble nor supersedes earlier full-campaign review flags.
It is not a matched before/after comparison, and no Ring rules were changed.

## Live Production Check

Railway deployment `85372f26-182f-4929-b029-78603539a874` reports `SUCCESS`
from runtime commit `01c5362dea176e86223548cacaec0332150e4323`, repository
`shary17454/kras-pass`, branch `main`, health path `/health` and `/data` volume.
The preceding deployment was removed during replacement, not treated as a
new deployment failure.

`https://kras-pass-production.up.railway.app/health` returned successfully:
`ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`.
The bounded deployment log showed startup and an existing Config-as-Code
deprecation warning. Existing configuration is reported supported until
2026-12-01. No configuration migration, secret change or duplicate deployment
was performed. This log window does not prove error-free lifetime operation.

## Unpassed Release Gates

- Production online play remains disabled. Four real internet peers,
  reconnect and host loss are not qualified by server unit tests.
- Xcode 27 `devicectl list devices` currently reports the physical
  iPhone 16 Pro Max unavailable. No application was installed or overwritten.
- Physical iPhone/iPad multiplayer, touch/gamepad orientations, sustained
  frame pacing, RSS, battery and thermals remain unqualified.
- All-game balance/content readiness, full replay fidelity/seek and native
  residual memory attribution remain incomplete.
- No archive, distribution-signature validation, upload, processing or
  App Review submission was performed for this source.

Continue with the full product requirements; these passing checks do not
change the requested completion scope or classify all 39 games as READY.
