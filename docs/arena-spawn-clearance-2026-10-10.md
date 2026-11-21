# Authored spawn clearance correction

## Proven defect and scope

Parent: `a007715b36b701e0ec163135715c1f15f35baf48`, branch
`feature/kras-online-random-rotation`. A real-body physics query at untouched
MatchScene starting transforms found two Duel Pit fighters overlapping ledges
and all four Iron Flats fighters overlapping pillars before movement began.

The tracked regression fixture constructs five actual game/arena configurations
(Duel Pit on both maps, Turret Duel, Boss Dreadnought and Base Siege), twice each
to cover all eight characters and all four seats. It freezes movement, waits
for physics registration, and queries the actual Body collision shape against
StaticBody3D geometry. It also requires starts inside the playable arena.
Base Siege's controller-specific starts were already clear; their behavior is
protected rather than claimed as newly repaired.

Before: 53 assertions passed, 28 failed, exit 1. No parse failure in this
regression run; failures identify real static intersections. After: 81 assertions
passed, exit 0, both stdout/engine guards passed.

## Changes

- `data/arenas.json`: explicit four-seat symmetric spawns for the two maps.
- Duel Pit uses radius 4.32 at height 1.4, inside the lowest ledge ring.
- Iron Flats uses radius 7.2 at height 1.4, clear of the pillar rings.
- `tests/suites/test_arena_spawn_clearance.gd`: real-scene regression coverage.
- `tests/test_runner.gd`: registers that suite in normal CI/full execution.

No arena scenery, walls, pillars, ledges, character stats, AI, physics constants,
acceptance thresholds, networking protocol, scoring or save schema were changed.
Other arena spawn definitions are untouched. Iron Flats is shared by four
games, so all four consuming games are included in the fixture/full test scope.
This proves initial clearance; it is not exhaustive respawn/controller/device QA.

## Current source and verification

Godot 4.7.1-stable (official), imported runtime `/tmp/kras-tank-pursuit-check`.
Selected gameplay fingerprint after the data change:
`72ad61069780e589372eb55c860c083d23cffc8b5f1d2910d0ec0801b50f45fa`.
Checkout/runtime checks match; the candidate report records the same start/end
fingerprint. This covers selected gameplay source, not tests/all assets/signing.

| Check | Result |
| --- | --- |
| Targeted regression | 81 assertions, 2.1 seconds, exit 0 |
| Fresh full suite | 408334 assertions, 397.4 seconds, exit 0 |
| Full-suite stdout/engine guards | Both pass in tests mode |
| Compile check | 451 scripts, exit 0, both runtime guards pass |
| Matched natural candidate sample | 146 completed instances, exit 0 |
| Candidate stdout/engine guards | Both pass |

Full-suite ERROR lines from intentional save/router failure injection and the
macOS system-CA startup message remain retained, not described as zero errors.

## Matched candidate balance sample

Default Duel Pit, four AI, seed offset 80000000, supplementary balanced rosters:
96 natural baseline + 48 mirrored difficulty + two mutated/chaos smoke instances.
All 96 seeds and baseline rosters equal the original pre-change sample. Both
smoke cases pass, elapsed report time 424.0 seconds. No source edits during runs.

| Metric | Before | Candidate |
| --- | ---: | ---: |
| Sakhra credited wins / 96 baseline matches | 30 | 21 |
| Character bias | 0.1875 | 0.09375 |
| Seat bias | 0.104166666666667 | 0.0208333333333333 |
| Expert point share | 0.636182902584493 | 0.64187866927593 |
| Mean natural duration | 63.6923611111088 s | 61.9821180555533 s |
| Ties / zero-score matches | 0 / 0 | 0 / 0 |
| Flags | character advantage | none |

Candidate wins by seat: 26,25,23,22. Character wins: Barq7, Fanoos18, Ghaim10,
Mowja7, Nabta9, Ramla11, Sakhra21, Turs13. Each character appears in 48 baseline
matches. These results do not erase historical canonical/held-out warnings or
prove every arena balanced. The previous alternate-Iron sample also had an
Expert-tier warning. Candidate held-out and other affected-map natural/network
qualification remain required.

## Evidence and remaining gates

Raw original reports, before/after/full-suite/compile logs and the external
spawn probe source/logs: `../qualification-duel-arena-pair-2026-10-10/`.
The temporary external probe first failed to infer a local variable type; that
attempt was stopped at exit 130 and retained. Its corrected attempt exited 0.
It is not a project failure or a qualifying completed-match test. The temporary
probe script/scene were removed before full-suite and compile execution.

The earlier adbb canonical 39-game and older network campaigns do not qualify
the new 72ad source automatically. No READY/DONE promotion, main merge/push,
production migration/deploy, new native archive, upload or Apple submission.
Stage 0 remains QA_PENDING/MERGE_PENDING and later feature stages stay locked.
Remaining acceptance includes current-source wider natural/network coverage,
physical devices/humans/controllers, backup/restore approval and release gates.
