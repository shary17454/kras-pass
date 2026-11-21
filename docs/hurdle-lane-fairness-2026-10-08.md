# Hurdle Dash: Equal Physical Courses

The authored track has seven hurdle rows. The previous `(row + lane) % 4`
gap rule placed six obstacles in the first starting lane and five in each
other lane. Partial lane cycles also made other row counts unequal.

The first attempted correction equalized counts, but kept staggered gaps.
Its 24-round natural sample still flagged spawn-slot advantage, with wins
`[5, 1, 14, 4]`. It was not accepted as a complete balance fix.

The final design gives every lane the same hurdle coordinates and a common
recovery row every four rows. The current seven-row track consequently has
six equally spaced physical hurdles per lane, with the same recovery gap.
No player stats, AI profile, RNG seeding, scoring, or acceptance threshold
was changed. This intentionally removes starting-lane course advantages,
not player skill differences. Lane positions and race controls are unchanged.

Regression tests inspect actual StaticBody3D/BoxShape3D obstacles, not just
the generation formula, for row counts 1 through 12. They verify counts and
longitudinal coordinates for all four lanes, alongside the existing finish,
rescue, restart and network-result tests. The final focused suite passes 122
assertions. All 423 scripts compile. Both logs pass the strict Godot guard.

## Balance Evidence, Not A Green-Check Claim

The final-course pilot at seed offset 2700000 still reports a spawn warning:
24 baseline races, wins `[6, 3, 12, 3]`, Expert placement share `0.7`.
The fresh offset 2800000 pilot also reports a spawn warning, but the leading
slot changes: wins `[7, 2, 4, 12]`, with one tied race.
Neither warning is discarded or relabeled as a pass.

A 192-baseline-race expansion at offset 2700000 was started, including all
24 original pilot seeds, to investigate remaining sampled concentration.
The sample-size-dependent null policy is unchanged. The expansion completed
in 272.5 seconds: 192 baseline races, 96 completed mirrored difficulty
comparisons, and successful mutator/chaos rounds. Slot wins were
`[50, 51, 47, 45]` (one tied race adds a second winner), Expert placement
share `0.699271592091571`, and no balance flags. The baseline seed prefix
matches the first pilot's 24 seeds. Both source start/end fingerprints match:
`ed4d18a506eacd11444c37d384019bdbd1be2a20ee07c56eb59c9934f62c5664`.
This larger sample qualifies only this game/configuration; it does not prove
all-game readiness or population win-rate equivalence.

The full verbose test suite completed 392261 assertions in 369.8 seconds,
exit zero, and passed the strict log guard. No leaked-object diagnostic was
reported in this run; this does not establish the cause of the preceding
source's intermittent shutdown warning.

Four actual Godot processes then completed a local WebSocket Hurdle Dash
match using scripted movement/jump inputs and the new physical course.
All peers reported matching centisecond finish scores `[1405,1410,1409,1409]`.
All moved, the host and one client reconnected, and the other clients applied
770 or 789 world snapshots. All peer logs passed the strict log guard.
The server's maximum recorded loop delay was 37 milliseconds, not a claim
about Internet latency or physical-phone performance. The match was not a
tournament and does not replace full tournament/production qualification.

Raw evidence is retained in `docs/qa/hurdle-lane-fairness-2026-10-08/`.
Rising Tide's earlier high-tie warning, the intermittent shutdown warning,
current-source all-game qualification, device/performance acceptance,
production rollout and signed local Xcode 27 release remain open gates.
