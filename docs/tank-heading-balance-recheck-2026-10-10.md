# Natural balance qualification after the ATV heading repair

Source: `d9c9c0a514990b5e27173efddf9678f6d0485b7f` on
`feature/kras-online-random-rotation`. Checkout and isolated simulation share
fingerprint `a6e844a59bf8df7945bc5a5edae0e5372d3595a914c54cf10fde47518a5e4ca8`.
Both completed reports retain identical start/end fingerprints and official
Godot 4.7.1. Processes exited zero; both strict log guards passed.

## Same-configuration expanded comparison

Before: the c46a7f1 runtime report in `expanded-balance-review-2026-10-10.md`.
After: 96 baseline, 48 paired difficulty and two mutator/chaos matches, all
completed. Offset 0, `seeded_partition_seat_rotation`. Structured comparison
confirmed identical baseline seed arrays, roster arrays, round windows,
difficulty pairing, engine version and run count.

| Measurement | Before | After |
| --- | --- | --- |
| Slot bias | 0.2193877551 | 0.0833333333 |
| Character bias | 0.0688775510 | 0.0833333333 |
| Expert share | 0.5958762887 | 0.5354166667 |
| Baseline slot wins | 46,11,29,12 | 24,15,25,32 |
| Average round seconds | 41.2078125 | 15.3189236 |
| Report flags | spawn slot advantage | none |

The only runtime diff from the before source is Tank Arena's call to inherited
round initialization instead of cleanup alone. No balance thresholds, damage,
characters or Bot skill changed. This sample supports an improvement from the
verified heading defect repair; it does not establish universal fairness.

A separate adjacent-rotation smoke sample completed 24 baseline, 16 paired
difficulty and two stress matches, flags empty, slot wins [5,5,7,7], expert
share 0.525. Its seeds overlap the expanded sample; do not count their combined
188 executions as 188 independent matches or two independent cohorts.
An independent expanded seed cohort and all-arena acceptance remain required.

## CI evidence and limits

Downloaded and inspected prior-source Core `38015873710` attests a clean
c46a7f1 checkout: 407356 assertions, 117 stability matches with zero failures,
and 276 capture-enabled server tests with zero skipped. Test and stability
stdout pass strict guards. The intentional memory-warning cache-drain message
remains in the log; this is not a zero-warning claim or device memory proof.
These artifacts predate the heading repair.

New-source Core `38017220130` and Tank networking `38017226293` were confirmed
in progress on d9c9c0a at this review. No completed result is inferred.

## Retained evidence and open gates

Local reports/stdout and the current-source review index are retained at
`../qualification-tank-heading-balance-2026-10-10/`. Prior-source Core artifacts
are retained at `/tmp/kras-core-c46a7f1-38015873710/`.

Blast difficulty and armed-race character balance remain unresolved. No stage
DONE, game READY, main promotion, Railway deployment, native archive, Apple
upload or review submission is claimed. The full product scope, physical
device/controller/thermal QA and production authorization remain open.
