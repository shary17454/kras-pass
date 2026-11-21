# Blast Ball Observation-Based Planning

Base release source: d0b40cb233662f0dc79fe914a40c6dcae416fa1e.
Tested runtime: 3f1823af75b6a31eedddfc26ea8c630e729fc0dd.
Branch: fix/kras-blast-survival-margin. No main merge or release upload.

## Retained Failure and Experiment

The unchanged release source reproduced the independent campaign warning at
seed offset 1200000: 24 natural baseline matches, 16 mirrored difficulty
comparisons and two mutator matches completed; Expert score share was 0.4625.
Report: /tmp/kras-current-110-blast-natural-report/report.json.

First experiment 4f3ac9096612b22bea5d1624a629ff8f5c52cf20 reserved time to
leave the public blast radius using the actor's own movement speed and decision
delay. Better strategy tempers risk rather than treating aggression as extra
escape time. Its same-offset sample improved to 0.5125, but retained
"expert bots no better than easy" and was NOT accepted as a balance pass.
Report: /tmp/kras-blast-margin-natural-report/report.json.

The second commit additionally uses the existing prediction profile to estimate
the ball trajectory from delayed visible position and observed velocity. It does
not read the ball's private momentum, change player speed, expose hidden rivals,
or eliminate offensive play. Extrapolation is bounded to a short horizon because
the ball can turn. Close contact still needs time to escape; a long visible fuse
continues to permit an approach.

## Results on Second Commit

| Seed Offset | Baseline | Mirrored Difficulty | Mutator/Chaos | Expert Share | Flags |
| --- | --- | --- | --- | --- | --- |
| 1200000 | 24 | 16 | 2 | 0.56875 | none |
| 1500000 | 24 | 16 | 2 | 0.55 | none |

Both processes exited zero and passed strict runtime log checks. Their source
fingerprints before/after were identical:
ba25854f89b88fb1b85f1324dfdcf2c5303471d4bb85cc506d614b5e3ca958e5.
Original failing seeds and thresholds were preserved. Reports are included as
blast-survival-natural-1200000.json and blast-survival-natural-1500000.json.

Targeted suite: 376 assertions passed. Tests retain viable offense, require
escape time even inside strike range, check slow-character movement budgets,
use observed trajectory, reject dependence on private velocity and handle
missing observed motion. An earlier targeted invocation used an unsupported
--only flag and began the full suite; it was interrupted with exit 130, not
counted as a pass. Correct --suite=blast_ball invocation passed.

The first experiment compiled all 415 scripts; the second commit's affected
script was parsed and exercised by the targeted suite. At this initial sample
checkpoint the full 39-game suite had not been rerun. Subsequent modified-source
qualification is recorded in blast-fixed-full-qualification-2026-10-07.md.
Parent release-source full regression alone does not certify modified behavior.
Current-source all-game acceptance, native device QA and production/release gates
remain open.

Two samples are not exhaustive balance proof. This is development evidence,
not sustained rendered FPS, heat, battery, four-person touch or Internet QA.
The archive for 1.1.11 (110) remains on d0b40cb and DOES NOT contain this fix.
Any release containing it needs a new frozen source and local Xcode 27 archive.
