# Duel public-life pressure experiment - preregistration

Status: PLAN / BASELINE RUNNING. This is not an implemented or accepted fix.

Base: source fingerprint
`27feb3b52380f75b29156edd2c20dfd6be0e9e65eac2d33ec92a9299c20d8e8b`.
The appearance changes remain intact. Git HEAD is offloaded; no commit, merge,
push or deployment is authorized by this experiment.

## Hypothesis

The current duellist utility prioritizes observed damage and proximity. A rival
with several stocks can remain largely unpressured while already fragile,
low-stock rivals are repeatedly targeted. This may contribute to the existing
character-advantage warning. It is a hypothesis, not an established cause.

## Candidate Fixed Before Comparing Results

Add a bounded history of visible HUD stock counts inside DuellistBrain only,
aligned to the existing movement/damage history ring. A cue is usable only
after the configured reaction delay and while its avatar is observable.
No hidden/unsampled stock values may be queried by target selection.

Preserve existing target utility and add:

`max(0, observed_target_lives - observed_own_lives) * 100 * strategy`

This adds pressure only when the bot trails that rival in visible lives.
Equal-stock decisions and the existing seeded final-tie rule stay unchanged.
The coefficient is fixed at 100 for this candidate, not tuned after viewing
its outcomes. Do not change character stats, collision response, damage,
round duration, scoring, difficulty profiles or acceptance thresholds.

## Evidence Plan

1. Current-source baseline: 112 pair-balanced natural baseline matches,
   56 mirrored Expert/Easy comparisons and two mutator/chaos matches.
   Seed offset 101000000, default Duel Pit, four AI, fixed physics at 60 Hz.
2. Focused regressions: delayed stock cue, missing controller, hidden target,
   unsampled future values, ring wrap/reset, equal-stock target stability,
   stock-leader pressure, and the existing AI visibility suite.
3. Candidate: the same 170-instance configuration and seed/roster assignments.
4. Proceed to independent acceptance offset 105000000 only if the matched
   candidate clears the existing character warning without introducing any
   other report/smoke/completeness warning. Difficulty must retain the existing
   placement-share threshold of 0.52 and more outright Expert wins than Easy
   wins in the 56 mirrored comparisons; report both metrics separately.
5. Independent acceptance must also satisfy those gates. Preserve all raw
   samples; do not pool examined and held-out samples to hide a failure.

Strict runtime logs must pass, source fingerprints must remain stable during
each campaign, and trace/report outcomes must match. Outright Expert wins and
placement-point share are reported separately. A lower bias number by itself
is insufficient. If a required gate fails, withdraw only this candidate and
its new test registration, retaining the appearance work and previous fixes.

No result here proves all 39 games READY, four-human device ergonomics, phone
thermal/battery performance, production stability or App Store submission.
