# Tank stationary engagement diagnostic - 2026-10-15

Status: diagnosis and regression coverage, not an AI gameplay correction.
Stage 0 remains QA_PENDING / MERGE_PENDING.

## Local execution context

The earlier isolated diagnostic contained a macOS system-CA initialization error
and remains rejected. A locally authorized Godot compilation then completed with
462 scripts and no such error. No Keychain, certificate, P12, TLS configuration,
network service or production data was changed.

The diagnostic was repeated locally with isolated HOME/save directories and the
same seed offset 99000000. This is a context-controlled repeat of the rejected
sample, not a second independent seed sample. All 170 instances completed in
159.2 seconds with exit 0 and passed the newly strict runtime log guard.
Gameplay source start/end both equal:
`d2371393a99fd6dca7c29aa5d8d0f6438806e1179055318d76ac7c4e917a0dd2`.

The local report gives baseline seat wins 41 / 20 / 27 / 24 and Expert point
share 0.408928571428571. Both spawn-slot and Expert warnings remain. The route
correction is not proof of universal outcome fairness. The earlier 96M/98M
campaigns must not be described as eliminating that warning for all seeds.

## Elimination observations

Analysis uses only the 56 difficulty comparisons (rows 112 through 167), not
the baseline or smoke rows. Slots are classified using each row's player config.
Planar speed below 0.5 at the elimination snapshot is called near-stationary.

| Observation | Expert | Easy |
| --- | --- | --- |
| First player eliminated | 51 | 5 |
| Recorded eliminations | 91 | 74 |
| Near-stationary at elimination | 76 | 14 |
| Total elapsed seconds over eliminated players | 610.583333 | 883.150000 |
| Total delivered damage over all configured players | 11404 | 8014 |

All 165 recorded eliminations had zero armor; none had edge distance below 3.5.
The elapsed sums are conditioned on elimination and are not mean lifetimes for
all players. Damage is accumulated per player from final match details. These
observations associate precise engagement with stationary exposure; they do not
identify the shooter of each hit, prove causation or establish observer neutrality.

## Rejected steering hypothesis

The hypothesis that the reverse fallback inverted stationary aiming was tested
without changing production code. It was NOT reproduced. The existing drive
helper uses the same steering polarity for forward/reverse fallback, and the
tank can rotate while stationary using its ordinary vehicle integration.

New regression `tests/suites/test_tank_stationary_aim.gd` uses an actual tank
match/fighter, a controlled visible target eight units away at four rear angles,
all four difficulty profiles and 361 ordinary drive-integration steps per case.
It verifies zero throttle, an initial turn toward the target, eventual alignment
and no free planar speed. Target selection/visibility are controlled in this
fixture; this does not qualify natural perception, firing accuracy or real input.

All 65 assertions passed on the unchanged production code. The log name contains
`stationary-red` because it was intended as a reproducer, but the actual outcome
was GREEN; it is not evidence of a fixed steering defect. Compilation with the
new regression completed at 463 scripts. Both logs passed their strict guards.
The prior full 425476-assertion run predates this new test; no new full-suite total
is claimed here.

## Evidence and next action

Sibling `../qualification-tank-stationary-2026-10-15/` preserves logs, JSON/HTML
report and the synthetic match trace only, not private player save files.

SHA-256:

- Report JSON: `64e2b58082045dcf30fd474cf50c215ba0bb3b7d89878c3fcec40a0752f8ad36`
- Trace JSONL: `f8165f4988aabf7560f4b3eee8e5169c788108ef1a7d81e3424a024e5c894eee`
- Regression log: `821dd205f8a6b5d4f5d978de1e6ef6316dd00f778ed2980e9593c6c890640b85`

Next: test an engagement-mobility candidate using own state and delayed visible
observations only, then compare matched and independent seeds before acceptance.
Do not alter scoring, character stats, difficulty thresholds or hidden perception
to make the report pass. No AI gameplay change, merge, push, Railway mutation,
Xcode Archive, upload or Apple review submission occurred in this stage.
