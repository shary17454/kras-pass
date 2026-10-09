# Rising Tide Water Perception

Parent: `474cab7`, branch `feature/kras-online-random-rotation`.
No main merge or deployment is part of this repair.

## Defect and Repair

Climber decisions read `arena.water_level()` directly while ground and
rivals already use delayed visible observations. Hidden or newly moving
water therefore bypassed the difficulty profile's perception delay.
`_perceived_water_level()` now delegates to the existing bounded
`perceived_object_position()` history for the actual RisingWater node.
Unavailable observations return `-INF`, preserving minimum urgency rather
than inventing a hazard height. Observations use world coordinates, matching
the fighter position used by the urgency formula.

No water speed, map, physics, AI profile, score, elimination rank or tie
threshold changed. The surviving simultaneous-elimination rule is retained.
This fixes information fairness, not the entire climbing/balance experience.

## Focused Evidence

Added four-tier checks in `test_climber_ground_perception.gd`: acquisition
delay, delayed moving height, hidden height exclusion, reacquisition after
visibility returns, and knowledge reset on a new round. The fixture disables
the camera to isolate the time/visibility contract; it is not screenshot QA
of water visibility through the real gameplay camera.

RED: 81 passed, one failed, exit 1 (missing delayed-water contract).
GREEN: 110 assertions passed, exit 0. Strict test log check passed.
Actual ordinary-jump/step-access fixture: 140 passed, exit 0; strict check
passed. All 442 scripts compiled and passed the runtime log checker.
Full regression completed: 405954 assertions passed in 212.5 seconds,
exit 0; strict log checker in `tests` mode passed. This qualifies local
test execution, not iPhone rendering, thermal behaviour or battery use.

## Natural Before/After

`tests/tide_trace.tscn` inherits the natural balance runner and only records
positions, peak height, alive/grounded state, observed ledge plan and water
height. Both runs used offset 6800000, 24 baseline matches, 16 matched
difficulty matches and two stress rounds: 42 each, 84 total.
Independent assertions confirmed identical baseline seeds and rosters.
Both processes exited zero and passed strict runtime log checks.

| Measure | Parent | Repaired |
| --- | --- | --- |
| Draws | 11/24 | 7/24 |
| Mean duration | 17.4729 s | 17.0903 s |
| Expert placement-point share | 0.7200 | 0.7159 |
| Winner credits by slot | [10,8,11,8] | [9,5,9,9] |
| Existing flags | ties 46% of the time | none |

All eleven parent baseline draws had multiple grounded survivors near
the 4.65 m summit in their last half-second trace sample. Water was then
about 4.397 m; those rounds ended shortly thereafter with equal top scores.
The trace does not record the exact elimination frame, so do not infer
sub-frame ordering from it. No timed-out or forced score result is inserted.
The existing scoring fixture separately proves same-water-tick victims tie.
Do not choose an arbitrary seat winner to lower the draw metric.

Small-sample flag clearance is not final balance acceptance. Summit tactics,
gameplay fun, actual-camera water acquisition and device QA remain open.

Parent start/end fingerprint:
`63751e709a6ee8d4239a8c2ca0d5bf8a1aa7f999019f33477888aa77a8b5d644`.
Repaired start/end fingerprint, independently recomputed:
`ae644771a1f32ea196218cc3012e896d8f7ea1fc6a88ece82aba36db89ac65b4`.
Older remote campaigns do not qualify this changed source.

## Local Real-Peer Network Check

`node network-smoke.js --game=rising_tide --humans=2 --seed=6809001`
completed exit 0 with a real loopback WebSocket service, two Godot peers
and two Bots under host authority. Both peers agreed on `[4,4,8,16]`;
host and guest both reconnected with their peer IDs retained. The guest
received 984 world snapshots. Both stdout logs passed the strict checker.
The existing fixture checks rising water, actual elimination and agreement
between replica water level/age and authoritative state. It uses a 45-second
test duration override, not the authored 120-second budget. Server maximum
event-loop delay was 29 ms; this is not production or iPhone FPS evidence.

Raw peer evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-55s3I2/`.
Reports, trace and regression logs and peer evidence are preserved outside
the checkout at `../qualification-tide-water-2026-10-09/`.

## Raw Evidence

Parent trace/report: `/tmp/kras-tide-474cab7-trace.stdout`,
`/tmp/kras-tide-474cab7-trace-report/`.
Repaired trace/report: `/tmp/kras-tide-water-candidate.stdout`,
`/tmp/kras-tide-water-candidate-report/`.
Focused logs: `/tmp/kras-tide-water-{red,green,jumps,compile}.stdout`.
Full regression log: `/tmp/kras-tide-water-full.stdout`.
No archive, signing, upload, processing or App Review success is claimed.
