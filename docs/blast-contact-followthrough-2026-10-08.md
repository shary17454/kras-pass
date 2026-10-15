# Blast Ball: Complete The Contact Approach

The attacking plan previously steered to a staging point 1.4 metres behind
the observed ball. The player's capsule radius is 0.42 metres and the ball's
radius is 0.62 metres. Ball deflection is overlap/contact based; a distant
attack alone does not push it. An aligned bot could therefore park outside
contact rather than complete its intended push.

After reaching the staging point, BallBrain now steers through the observed
ball position toward the observed rival. The existing visible-fuse budget,
escape behavior, reaction delay, movement stats and difficulty profiles are
unchanged. No private ball momentum or hidden opponent data was added.

The regression passed the initial line-up assertion but failed follow-through
on the previous implementation (378 passed, one failed). After the change,
all 379 Blast Ball assertions pass, with the strict Godot log guard. All 423
scripts compile. This is plan/target evidence, not physical-phone touch QA.

The first full-suite run completed 392165 assertions, exit zero, in 297.8
seconds, but reported one leaked ObjectDB instance at exit. Its strict log
guard failed. It is retained as a failed shutdown qualification, not counted
as a clean full-suite pass. A verbose diagnostic run was then started from
the same unchanged application/test source to identify the object.
That verbose rerun completed 392165 assertions in 301.0 seconds, exit zero,
and passed the strict log guard without a leak diagnostic. The first warning
was not reproduced and its object type therefore remains unknown. No audio
shutdown delay, log suppression, or acceptance-rule change was introduced.
The intermittent shutdown warning remains a qualification risk to investigate,
not a bug claimed fixed by the gameplay change.

## Natural-Round Samples

Godot 4.7.1 official on macOS, fixed simulation rate 60. Each sample includes
24 baseline rounds, 16 mirrored Expert/Easy comparisons spanning all eight
characters, and one mutator plus one chaos round. No clipped durations or
changed acceptance thresholds were used.

| Seed offset | Expert placement-point share | Balance flags |
| --- | --- | --- |
| 2700000, earlier campaign | 0.51875 | expert bots no better than easy |
| 2700000, follow-through change | 0.54375 | none |
| 2800000, fresh seeds with follow-through | 0.5375 | none |

Both new reports have identical start/end source fingerprints:
`0c0d2879cc01183b0e7e11f3f2ab76e464da18aea76044ae5a8643303ddaf98e`.
They include the preceding Scrap Karts braking fix.

The earlier campaign belongs to commit
`f2dcfd32b8cda63d68c3a9ea7a52958b6fda3840`, run `37734724695`,
fingerprint `39854bc0220d9911c43a4fce98c0d35dcc562dae73d196c9475c213c06d98e93`.
It is historical campaign evidence, not a new-source qualification or a
same-platform controlled baseline. Sampled placement shares do not prove
population win rates or certify every arena/character combination.

Raw evidence is retained in `docs/qa/blast-contact-followthrough-2026-10-08/`.
All-game current-source qualification, production online rollout, real-device
performance and input QA, exact-source signed local Xcode 27 archive, upload,
processing, and review submission remain separate release gates.

## Broader Campaign Is Still Incomplete

The existing source-398 campaign was re-read during this work. Its partial
summary validates 27 of 39 games, not 39. In addition to the two historical
AI-tier warnings addressed in the new narrow samples, it reports:

- `hurdle_dash`: spawn-slot advantage, baseline wins `[5, 2, 13, 4]`.
- `rising_tide`: ties in 10 of 24 baseline rounds (41.6667 percent).

These are retained as open investigations, not dismissed because their CI
jobs succeeded. The campaign's commit/fingerprint above is kept on the
partial summary. Neither that campaign nor the new two-game samples proves
all-game release readiness.
