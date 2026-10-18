# Rejected vehicle cruising-speed experiment

## Current source and decision

Base commit: 59026879c360ecb8bc83dbce1f76fc6b2f5adb2d.
The temporary candidate was rejected, and only its three intentionally changed
files were restored with explicit patches. No user work was reverted.
The current simulation fingerprint is again
`4a828a1cc9142dca43b62b3873e60a701d919696bb826e2e0b936435d3141140`.
No gameplay change from this experiment is included in this documentation commit.

## Independent diagnostic cohort

64 natural baseline races used seed offset 6400000 and
`seeded_partition_seat_rotation`. Each of the eight characters appeared eight
times in each of the four seats, independently checked from raw rosters.
32 paired difficulty matches and two mutator/chaos matches also completed.
Source start and end fingerprints matched the current fingerprint.

Character wins: barq 18, fanoos 8, ghaim 12, mowja 4, nabta 10, ramla 8,
sakhra 2, turs 2. Slot wins [17,12,17,18]. Character advantage remained flagged;
no slot warning, ties 0, Expert edge 0.70, average simulated duration 129.02s.
This supports investigating character dynamics rather than assuming the old
adjacent-roster composition alone caused the warning. It is not all-game QA.

## Temporary candidate

- `drive_speed_stat_scale`: 0.35 -> 0.2 in tuning.
- Fighter fallback for that value: 1.0 -> 0.2.
- Effective-budget test: cruising ratio 0.94..1.06 -> 0.97..1.03, with
  expected formula factor 0.2 instead of 0.35. Neutral values were unchanged.
- Candidate simulation fingerprint:
  `0a9b008bad5f2c1407098caa6062d9d174581c4ebd066abe15c2ebf3ddda9ab1`.

RED: 105 assertions passed, eight failed against the new candidate contract.
GREEN: 113 passed, strict log check passed.
Candidate full regression: 405309 passed in 267.9s, strict log check passed.
These test results belong to the rejected candidate, not a shipped improvement.

The candidate repeated exactly the same 64 baseline seeds and rosters, with
another 32 difficulty matches and two stress matches. Source stayed unchanged
during measurement; strict log check passed. Both campaigns totaled 196
actual simulated matches, not thousands of matches or human/device sessions.

| Character | Original | Rejected candidate |
| --- | --- | --- |
| barq | 18 | 17 |
| fanoos | 8 | 4 |
| ghaim | 12 | 14 |
| mowja | 4 | 7 |
| nabta | 10 | 4 |
| ramla | 8 | 10 |
| sakhra | 2 | 4 |
| turs | 2 | 4 |

Candidate slots [14,20,13,17], ties 0, average simulated duration 128.60s,
Expert edge 0.70. Mutator and chaos passes succeeded. Character advantage
remained flagged in both campaigns. The modest redistribution is insufficient
evidence to retain a change affecting all DRIVE games. No threshold was relaxed
or warning hidden. Acceleration, steering, perks and weapon interactions remain
diagnostic targets; this experiment does not establish which causes dominance.

## Linux tank diagnostic

Run 37910182246 completed successfully for exact source 5902687.
The tank-only networking job succeeded, including ordinary matches and recorded
remote, two-contender and three-contender finals. The latter finished at epoch 4
with scores [200,100,500,300], champion slot 2, unchanged points [10,7,10,10]
and cups [2,1,2,2], and host/guest reconnect. Artifact ID 11606632837.
This independently supports the test-pilot correction. The old failed run
37890891082 remains failed. Tank-only diagnostics are not the full release gate.

## Evidence and open gates

Raw original/candidate reports, RED/GREEN/full logs and Linux job log are in
`../qualification-rejected-cruise-2026-10-09/`.
The original character balance issue remains open. Complete product scope,
current-source all-game qualification, physical iPhone/iPad QA, production
backup/restore authorization and Railway synchronization, local Xcode archive,
upload and App Review submission are still not complete.
