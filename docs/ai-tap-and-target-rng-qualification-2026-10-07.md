# AI tap requests and target RNG qualification

## Scope and source

This is an incremental candidate, not a release approval. Worktree:
`/tmp/kras-ai-tap-actions`, branch `fix/kras-ai-tap-actions`.
No merge to main, production deployment, device installation, archive upload,
or App Review submission was performed in this qualification.

Tap runtime source: `bf9d8313f09f4805ee1dbe0bbc827719273cb44f`.
Subsequent seeded-target correction and fixture source:
`a640663ad05fd4f0e06482680b06575f0dd1a11f`.
Earlier archive evidence does not qualify either source.

## Tap input repair

Gunner repeatedly held ATTACK, but Turret Duel consumes `just_pressed`.
A stationary actual-controller diagnostic observed one click and 180 held
frames over three seconds. This diagnostic isolates input, not match balance.
The new `tap` request is consumed once when publishing an AI frame; persistent
held actions remain separate. Zone and Boss Hunter publishers also consume
pending taps. Gunner uses this API; Tank's held fire remains unchanged.

Initial focused regression: 5 passed, 8 failed.
Expanded repaired suite: 34 passed. Reload limits remain enforced.
Evidence: `/tmp/kras-tap-red.stdout`, `/tmp/kras-tap-expanded.stdout`.

Full gate on bf9d831: completed with exit zero in
`/tmp/kras-party-check.s1Tjq9`; 389917 assertions, zero inventory issues,
three-lap race, six boss checks, and 39 stability matches passed.
Server: 204 passed, zero failed/skipped, 2149.969416 ms,
`/tmp/kras-tap-server-tests.log`. Dependency audit total: zero,
`/tmp/kras-tap-npm-audit.json`.
These checks do not establish device FPS, battery consumption, or temperature.
The headless environment emits a macOS CA-certificate diagnostic; the runtime
log guard excludes that diagnostic and is not a blanket absence-of-errors claim.

## Natural matched-seed qualification

Each sample uses offset 1200000, 24 baseline matches, 16 paired difficulty
matches, and two mutator smoke matches. Paired seeds and 272-file source
fingerprints were independently validated. Both bf9d831 reports use fingerprint
`386184ae66db000f047a36bc669f1e71d3dcdb85f924beb23375fc5a390c0120`.

Turret Duel expert share: 0.652694610778443; no report flags. Aggregate results
are identical to the earlier parent sample: no general improvement is claimed.
Raw report: `/tmp/kras-tap-turret_duel-1200000-report/report.json`.

Fawda expert share: 0.5125, flagged expert no better than easy.
Raw report: `/tmp/kras-tap-fawda-1200000-report/report.json`.
Before the meaningful-leader policy, same-seed source 42c852d yielded 0.5375
without that flag. After the policy (80ed9ea), it yielded 0.5125, unchanged by
the tap repair. This is a candidate regression, not evidence of readiness.
Parent report: `/tmp/kras-leader-parent-fawda-1200000-report/report.json`.
Policy report: `/tmp/kras-leader-fawda-1200000-report/report.json`.

## Seeded target correction

The tied-score early return removed a random draw used by the prior policy.
The correction retains that draw while selecting the nearest eligible rival
instead of chasing a distant co-leader. It does not alter perception, difficulty
parameters, movement speed, damage, or the qualification thresholds.

Initial RNG-budget test failed for all four tiers. Two subsequent fixture runs
also failed because the reference omitted the co-leader tie-breaking draw;
these failures are retained in `/tmp/kras-leader-rng-green.log` and
`/tmp/kras-leader-rng-green2.log`, not called green checks.
The corrected reference models the three visible co-leaders and seed/state.
Final focused suite: 1165 passed (`/tmp/kras-leader-rng-green3.log`).
Tap suite rerun on a640663: 34 passed (`/tmp/kras-rng-tap.log`).
Natural Fawda follow-up completed: 42 matches with paired seeds verified,
expert share 0.50, still flagged expert no better than easy. Source fingerprint:
`37d2800b5d7594f7928a5a42457657a60d5f5b7a56a0cb375a1915600ffea167`.
Thus restoring the draw budget alone does NOT resolve the observed regression.
This candidate is not accepted for release. The fresh full gate on a640663
FAILED: compilation passed (420 scripts), inventory passed (519 resources,
zero issues), and 389921 assertions completed in 620.0 seconds, but Godot
reported one leaked ObjectDB instance on exit. The strict log guard correctly
returned failure and stopped before the race/boss/stability stages. Evidence:
`/tmp/kras-rng-full-gate.stdout`, `/tmp/kras-party-check.fwV8tr/tests.stdout`.
The leak cause is not established. It must not be dismissed as harmless or
silenced, and a focused verbose reproduction is required. The earlier bf9d831
full gate does not qualify a640663.
The subsequent meaningful-leader suite under `--verbose` passed 1165 assertions
with a passing strict log guard and no leak warning. Evidence:
`/tmp/kras-rng-verbose-focused.stdout`. This does not reproduce or clear the
full-suite leak; broader verbose diagnosis remains necessary.
Raw reports are retained in `docs/qa/ai-tap-target-rng-2026-10-07/`.

## Delivery

The isolated branch was pushed successfully after the earlier write failures.
Draft PR: https://github.com/shary17454/kras-pass/pull/187
Base: `fix/kras-survivor-winner-contract`, not main. The PR body explicitly
records the balance regression and the failed full gate. Automatic task
attachment failed because the thread has reached its 100-attachment limit;
existing attachments were not deleted. This is engineering review, not Apple
App Review, and no release readiness is claimed.

## Remaining gates

Current all-game balance, native local/touch/gamepad/orientation qualification,
production online and reconnect validation, protected backup/restore approval,
final main promotion, frozen release source, local Xcode 27 archive/signature,
App Store Connect processing and actual submission remain incomplete.
The Mac was locked during the latest attempted App Store Connect inspection.
No P12 import, certificate replacement, or Xcode Cloud action was attempted.
