# Rejected tank reload-spacing candidate - 2026-10-15

Status: REJECTED; no gameplay change retained. Stage 0 QA_PENDING / MERGE_PENDING.

## Candidate

Starting from e8f232dc05857274a0a9b44af3379c4ea07e8d77, tested a short reverse
movement while the tank's own weapon was reloading. It required a visible close
target ahead and scaled with the existing strategy profile. It did not read rival
cooldowns, alter damage, vehicle physics, character stats, scoring or difficulty
thresholds. A bounded `reload_remaining(slot)` controller query exposed own state.

Candidate gameplay fingerprint:
`f525f299718ca085d415098bc7a961ede6c77bd68f2a2ac14c80583b01cb034c`.

The first fixture attempt had a type-inference parse error, fixed in the fixture
before collecting the behavioral baseline. On unchanged production code the
expanded suite had 241 passed / 16 failed. With the candidate it passed 257
assertions and the strict test-log guard. This demonstrated the new behavior,
not its suitability for natural play.

## Natural matched comparison

Same seed offset 96000000 as the accepted route-correction baseline. Programmatic
comparison verified identical 112 baseline rosters/seeds and all 56 difficulty
seed/character/Expert-slot configurations. The candidate also completed two
mutator/chaos instances: 170 total, exit 0, 168.9 seconds, strict runtime guard
passed, with equal source fingerprints before and after. No source edits occurred
during the campaign.

| Metric | Baseline d237 | Candidate f525 |
| --- | --- | --- |
| Expert point share | 0.4135472371 | 0.4822064057 |
| Seat wins | 39 / 18 / 36 / 19 | 41 / 16 / 34 / 21 |
| Slot bias | 0.0982142857 | 0.1160714286 |
| Average baseline duration | 16.4708333 | 18.2563988 |
| Expert warning | yes | yes |
| Spawn-slot warning | no | yes |

Expert improved in this sample but remained below the existing 0.52 threshold;
the seat warning also appeared. This is insufficient for acceptance. No causal
claim or statistical significance is inferred from a single campaign. No further
tuning or independent validation was performed on this rejected version.

## Restoration

Removed only this experiment's two production additions and its added reload
fixture, preserving the previously committed stationary-aim regression. Git
confirmed no remaining production/test diff from the starting commit. Re-synced
the isolated runtime and verified its gameplay fingerprint returned to:
`d2371393a99fd6dca7c29aa5d8d0f6438806e1179055318d76ac7c4e917a0dd2`.
The restored stationary-aim suite passed 65 assertions and its strict log guard.

## Evidence and remaining work

Sibling `../qualification-tank-reload-candidate-2026-10-15/` retains the candidate
copies of tank_brain.gd, tank_arena.gd and test_tank_stationary_aim.gd, initial
parse/baseline/green/restored logs and the natural campaign JSON/HTML and log.
The rejected files are evidence only, not active source or proposed release code.

- Candidate report SHA-256: `7e645065b6ff476e67b041415003815b39658ad3e3e4034f3ad449d17c72c39e`
- Candidate engine log SHA-256: `0f4d88366deaf9f608e9852b9a2ecaf2f4d3a28fc67f64f4235207c3386e81b0`

The stationary-exposure problem and Expert balance remain unresolved. A future
candidate must address engagement choice/spacing without worsening fairness and
must pass matched and independent campaigns before being retained. Device and
production qualification remain open. Requested information about a production
database backup/restore location is still needed before the previously blocked
deployment path can be reconsidered. No push, merge, Railway mutation, Archive,
App Store upload or Apple submission occurred.
