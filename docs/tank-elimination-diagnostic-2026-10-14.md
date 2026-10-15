# Tank elimination diagnostic

Status: DIAGNOSTIC_COMPLETED / BALANCE_NOT_ACCEPTED.
Stage 0 remains QA_PENDING / MERGE_PENDING. No READY or release promotion.

## Instrumentation

Added tests/balance_tank_trace.gd and its scene as a supplementary driver of
the existing natural pair-balanced simulation. It listens to player_eliminated
and copies elapsed time, elimination order, armor, ammunition, shell types,
body positions/velocities and arena-edge distances at the event. It does not
publish input, call physics advancement, write game state or consume RNG.
Snapshots are appended to a JSONL file only after each match ends.

The unit suite checks independent deep copies, valid places/slots, duplicate
rejection, match reset and no event subscription at construction. It passed
16 assertions, exit 0, strict log guard. Compile passed 460 scripts, exit 0,
strict guard. The earlier complete 419583-assertion run precedes this fixture
addition; it is not a fresh full-suite run of the updated test runner.

Base source commit before edits:
`e5796437868f75b050d2349f06ad523927de1dff`.
Only test files changed; gameplay fingerprint remained
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
The isolated runtime originated from archive ab04d37; e579643 added documents
only. Fixture hashes matched before and after both campaigns:

- driver: `b72e9923872ea85160d85d96bf02e9c90a88b9e8de5d12fca4013c7b4f138733`.
- scene: `a5f5e7704f54135afb5ba69ad45e74444d1de2f217a1f538f5c278a63afd945d`.
- unit suite: `eb26b00a6cce550fd7d4e8f8d48e89e01563017e7d411f9341d8437eaad7b211`.
- runner: `cbb6b75e099a1d1741e41c89c7f33c764c435bda2649642eaae3011eaae0102a`.

## Campaign And Result Differences

Oasis, Godot 4.7.1, fixed FPS 60, natural durations, 112 baseline matches,
56 difficulty comparisons and two mutator/chaos matches. Seed offset 96000000
and roster scheduling match the previous campaign. Instrumented execution
completed all 170 rows in 372.6 seconds, exit 0, runtime log guard passed.

The ordinary simulation was then repeated without the observer, using a fresh
save directory and identical settings. It completed 170 instances in 397.7
seconds, exit 0, runtime guard passed. No overlapping processes or source edits
occurred during either campaign. Both reports' start/end gameplay fingerprints
match. All three campaigns retain the same two balance flags.

| Metric | Original ordinary | Instrumented | Ordinary repeat |
| --- | --- | --- | --- |
| Seat wins | 40/14/37/21 | 41/13/38/20 | 41/13/37/21 |
| Average simulated duration | 16.379464 s | 15.670238 s | 16.380655 s |
| Expert point share | 0.4267857143 | 0.425 | 0.4285714286 |
| Difficulty score rows differing from original | 0 | 1 of 56 | 2 of 56 |

The ordinary rerun also differs, so observer code is not established as the
sole cause. Exact outcome neutrality/determinism is NOT proven. Do not pool
these repeated seeds as independent balance evidence or use this trace as an
exact causal counterfactual. Wall-time differences are not phone performance
measurements. Preserve all results rather than selecting one green rerun.

For both new campaigns, profile, backup and settings MD5 envelope checksums
and schema 2 were externally verified. No secret values were printed or copied.

## Observed Eliminations

All 170 trace rows completed. The ledger contains 508 eliminations, all with
zero victim armor. Valid slot/place, unique victim and agreement with the
runtime elimination order were externally checked. Some matches end with
more than one survivor; 508 is not rounded up to an expected 510 events.

Across the 56 difficulty matches only:

- Expert: 91 recorded eliminations, first eliminated 47 times, average
  elimination time 7.782234 seconds.
- Easy: 76 recorded eliminations, first eliminated nine times, average
  elimination time 12.610307 seconds.

This supports investigating combat exposure/survival rather than initial
spawn overlap or falls. Average exit times condition on eliminated players
and exclude survivors; they are not unconditional lifespan averages.
It does not prove which attacker, route or aim decision caused each loss.

## Next Work And Release Gates

Review defensive response to visible incoming fire, close-range exposure and
route choices. A gameplay candidate needs targeted regressions plus matched
and independent samples on all three tank maps, with unchanged scoring and
acceptance thresholds. The current trace is diagnostic, not a balance fix.

No gameplay stats, score formula, physics, AI, maps or thresholds changed.
No main merge/push, production operation, signed archive, upload or review
submission. Device QA and production backup/restore approval remain open.

## Evidence

Preserved outside Git: ../qualification-tank-elimination-trace-2026-10-14/.
Contains compile/unit/campaign logs, both report directories and tank-trace.jsonl.
Original save directories remain under /tmp; their settings are not copied.

- Trace SHA256: `60f4d6542246636e7b6d8ed32235d7dbf9ea5cef5c9a1d4d4fb781624e99c3b4`.
- Instrumented report: `b605c03e9321c568ba25b4cea37d7e6b2646c031b25109749b20640364f90c56`.
- Ordinary repeat report: `39371206d4c7992a85be4cff0643eee338361eff012d9902ce6513dddcd67e79`.
