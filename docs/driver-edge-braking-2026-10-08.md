# Scrap Karts: Brake Before A Lethal Edge

The existing emergency retreat selected an inward steering target, but
`drive_to` still held forward throttle while turning a moving, outward-facing
kart. A regression reproduced the problem in all four cardinal directions.
The original implementation passed 29 assertions and failed those four.

DriverBrain now reserves stopping distance using the actor's own velocity,
acceleration, decision interval, and visible arena geometry. When its nose
points away from the retreat target and there is insufficient floor left,
it brakes using the normal reverse-throttle input. Steering is retained.
An already inward-moving kart continues forward. No character stat, AI
difficulty profile, score rule, physics budget, or balance threshold changed.

The extended test also steps the shared vehicle physics and verifies that
outward momentum decreases. The focused suite passes 37 assertions; all
423 scripts compile. Logs passed the strict Godot log guard.
The complete local test suite subsequently passed 392163 assertions in
277.9 seconds, exit zero, with the same strict log guard. The first sandboxed
engine launch failed while opening its user log and crashed before running
tests; it is not a test result. The local macOS retry and all qualification
runs used isolated test-save directories and completed successfully.

## Natural-Round Samples

Godot 4.7.1 official, fixed simulation rate 60, 24 baseline rounds per sample,
16 mirrored Expert/Easy comparisons covering all eight characters, plus
mutator and chaos rounds. Each report has matching start/end source identity:

`b0b5d150e074a16197820cf69a06280ad0b95492f2c489aec2c777176290a522`

| Seed offset | Expert share of placement points | Balance flags |
| --- | --- | --- |
| 2700000, original held-out report | 0.475 | expert bots no better than easy |
| 2700000, braking change | 0.53125 | none |
| 2800000, fresh seeds with braking | 0.559006211180124 | none |

The original report belongs to source
`f2dcfd32b8cda63d68c3a9ea7a52958b6fda3840`, campaign `37734724695`,
fingerprint `39854bc0220d9911c43a4fce98c0d35dcc562dae73d196c9475c213c06d98e93`.
It is retained separately, not relabeled as evidence for the new source.
These sampled placement shares are not a population win-rate guarantee or
qualification of every arena and character combination.

## Remaining Gates

Blast Ball's campaign warning remains open (placement share 0.51875 versus
the unchanged 0.52 policy). No Blast Ball behavior was changed by this fix.
The full current-source campaign, production online rollout, physical-device
performance and ergonomics, latest-source signed local Xcode 27 archive,
upload, processing, and review submission remain separate requirements.
