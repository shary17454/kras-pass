# Siege perception regression and independent natural sample

## Scope and source

Parent `2b7df891feb7fdc3ff01f01d9af4d1d89a142e58`, branch
`feature/kras-online-random-rotation`, origin
`https://github.com/shary17454/kras-pass.git`.
Godot 4.7.1-stable (official), isolated imported runtime
`/tmp/kras-tank-pursuit-check`. This phase changes tests and documentation only;
no production AI, character properties or acceptance thresholds changed.

Inspection of SiegeBrain and BaseSiege confirms base_observation checks the
crystal's observable geometry before returning a cue. _base_cue retains timed
observations, returns only samples older than reaction_time, and clears history
when the crystal is hidden or its instance identity changes. This specific
path is not proof that every AI object query is fair.

## Added tests

The existing AI visibility suite now includes 16 assertions per difficulty,
64 new assertions total. It constructs an actual BaseSiege MatchScene and its
crystals, freezes the match/fighter physics, and uses each configured profile's
nonzero reaction_time instead of disabling the delay.

Cases: first sight and exact delay threshold; delayed change of rendered health;
hidden destruction; cue-history invalidation; reappearance without previous
sight credit; replacement crystal identity with its own observation delay;
round restart without previous actionable history. Explicit clock advances
isolate the cue contract, not complete decision/physics timing.

The new fixture has no observation camera to isolate visibility/history from
frustum and ray behavior. Existing camera/occlusion tests in the same suite still
run. This does not add a physical-screen perception or player-performance claim.

Result: AI visibility suite 4396 assertions, exit 0, 2.7 seconds; stdout and engine
strict guards pass. Compile check 450 scripts, exit 0, both guards pass.
The earlier full suite's 408190 assertions precede these 64 new tests; it is not
relabeled as a fresh full-suite execution for this test-only phase.

## Independent natural balance evidence

Seed offset 72000000; base_siege, default arena, four AI, balanced rosters.
96 natural baseline + 48 matched/mirrored difficulty + two mutator/chaos smoke
matches = 146 completed instances, terminal exit 0, 196.0 seconds. Both smoke
cases pass. Strict stdout and engine guards pass.

| Metric | Result |
|---|---:|
| Expert point share | 0.556452 |
| Character bias | 0.050258 |
| Seat bias | 0.038660 |
| Mean baseline duration | 23.152431 seconds |
| Baseline tie rate | 1/96 |
| Zero-score baseline matches | 0 |
| Report flags | None |

Wins by seat are 26,28,23,20: the total is 97, not 96, because the one tied match
credits shared winners. Character wins: Barq15, Fanoos10, Ghaim10, Mowja11,
Nabta9, Ramla17, Sakhra13, Turs12. Do not interpret these as 97 matches.

Pre/post report source fingerprint and checkout/runtime checks match:
`adbbda6d74c6f6d6fb5f508ec50970e3123381f34a38f28329759d57b75ad1dd`.
It covers selected src/scenes/data/tools types and project.godot, not tests,
all assets, signing or a native archive. Only test edits above the parent were
present during this campaign; gameplay came from that parent.

Roster policy seeded_partition_seat_rotation is supplementary, not canonical
adjacent_rotation qualification. The earlier canonical sample's Expert share
0.518293 and warning remain retained for its original seed/source. This larger
independent sample changes the next action toward wider balance/human review,
not an unsupported AI-statistics retune or a READY promotion.

## Evidence and remaining work

Raw report JSON/HTML and successful test/compile/campaign logs:
`../qualification-siege-cue-history-2026-10-10/`.
Remaining: current-source canonical 39-game campaign, broader independent
balance review, current-source multi-peer and physical-client/device acceptance,
production backup/restore and deployment gates, fresh local Xcode archive,
verified upload and review submission. Existing source-qualified evidence stays
separate; no main push, deployment, native build or Apple submission in this phase.
Stage 0 remains QA_PENDING/MERGE_PENDING and later stages are not promoted.
