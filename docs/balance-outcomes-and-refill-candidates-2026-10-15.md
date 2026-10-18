# Difficulty outcomes and rejected refill candidates - 2026-10-15

Status: reporting improvement; no accepted AI gameplay change.
Stage 0 QA_PENDING / MERGE_PENDING. Base commit:
`09297e9` on `feature/kras-online-random-rotation`.

## Two rejected experiments

Close combat currently holds a firing position rather than chasing a weapon
crate. Tested two changes, each on a frozen source with isolated synthetic saves:

1. Always approach an already perceived available crate. Existing availability
   suppresses crates while own special ammo remains. This did not reveal crate
   contents or bypass visibility, occlusion or reaction delays.
2. During close combat, approach only if the delayed crate distance is below
   75 percent of the rival distance; otherwise retain the original behavior.

The first regression against original code had 431 passes / 8 failures, then
439 passes with candidate 1. Candidate 2 had 435 passes / 4 failures on original
code, then 439 passes. The distant-crate assertion was deliberately different
between experiments: candidate 1 sought it, candidate 2 retained combat. These
were separate behavioral hypotheses, not a changed balance acceptance threshold.

Each natural campaign completed 170 instances: 112 baseline, 56 mirrored
difficulty comparisons and two mutator/chaos probes. All 170 seed, arena and
roster configurations were programmatically matched to the preceding oasis
baseline. Exit 0, strict runtime logs passed, equal start/end source fingerprints,
and no overlapping code/test edits. Commands used Godot 4.7.1 with
`tests/balance_tank_trace.tscn --only=tank_arena --arena=tank_oasis --runs=112 --seed-offset=99000000`.

| Metric | Baseline | Always refill | Nearby refill |
| --- | --- | --- | --- |
| Expert placement share | 0.4125 | 0.4616755793 | 0.4071428571 |
| Seat wins | 41/20/28/23 | 27/36/31/20 | 44/24/24/20 |
| Slot bias | 0.1160714286 | 0.0657894737 | 0.1428571429 |
| Average baseline duration | 17.3355655s | 42.7538690s | 17.5251488s |
| Baseline tie rate | 0 | 0.0178571429 | 0 |
| Expert warning | yes | yes | yes |
| Spawn-slot warning | yes | no in sample | yes |

Neither met the unchanged 0.52 placement-share criterion. Always-refill also
lengthened matches substantially; nearby-refill did not improve Expert or seat
outcomes. Both were removed. No independent sample or full-suite qualification
is claimed for either rejected candidate. Only owned experimental edits were
removed; the original brain and crate suite match HEAD and the restored runtime.

Rejected fingerprints:
- Always refill: `58d832435ca4269c8498238bf37d7029eb13439485375c547b7d605064b9005e`
- Nearby refill: `be956c1c211fd61782c0524643d8b13ee612249bf2dbf8fc7c68423032d91969`

Reports SHA-256:
- Always refill: `c85c13c2990fc245b5b4383bb74c9270e09196eab2ceff18728c2084dfc17af3`
- Nearby refill: `43d6e2d69aa02cbe53efce6421feaa60b76af8a9251d5aa0235799e94884db59`

Copies of the rejected source/tests, logs, reports and synthetic traces are in
the sibling workspace directory `qualification-close-refill-2026-10-15/`.
These copies are not active release code.

## Reporting defect and retained change

The old HTML described 50 percent of aggregate finishing-place points as meaning
the difficulty tiers do nothing. That inference is not justified: Expert can
finish first and fourth while Easy finishes second and third. Both difficulty
groups then receive five 4-3-2-1 placement points, despite the Expert winner.

Added pure `difficulty_outcomes(samples)` and a `difficulty_outcomes` JSON field.
The HTML now shows the existing placement share beside Expert/Easy outright
wins. It separately counts shared first, incomplete and invalid samples. Team
partners or cooperative co-winners sharing first are not mislabeled as a true
opposing-side draw. The outright share excludes those ambiguous/unfinished
outcomes; an empty denominator is null, not a fabricated 50 percent.

Validated completed flags, four places and two distinct Expert slots before
classification. Nonfinite/fractional/bool/string/out-of-range numbers are not
silently coerced. Valid JSON numeric evidence is normalized only after bounds
checks. No input evidence is mutated. Existing flags, thresholds, scoring,
seeds, roster schedules and gameplay are unchanged. A regression explicitly
proves high outright wins cannot bypass the placement-share warning.

Godot re-counted the actual saved reports with the new implementation:

| 56 difficulty samples | Expert unique wins | Easy unique wins | Shared first |
| --- | --- | --- | --- |
| Original oasis | 20 | 36 | 0 |
| Previously rejected damaged-spacing | 36 | 18 | 2 |
| Always-refill | 29 | 26 | 1 |
| Nearby-refill | 21 | 35 | 0 |

All had zero incomplete/invalid difficulty samples. The original warning lists
were retained. These supplementary counts neither revive a rejected candidate
nor establish independent balance, statistical significance or physical-device
quality. They make the next decision more informed instead of selecting a
single favorable metric after observing the result.

## Tool qualification

Focused balance suite: 7690 assertions passed, exit 0, strict test guard passed.
All 466 scripts compiled, exit 0, strict runtime guard passed. An initial test
edit incorrectly moved an existing local-variable cleanup into a helper; this
parse error was fixed without dropping the old assertions. A subsequent JSON
fixture caught float/int Array membership classification; explicit conversion
after validation fixed it. Neither failed run is qualified evidence.

A separate natural integration smoke completed 20 instances (two baseline,
16 difficulty, two mutator/chaos), exit 0 and strict runtime guard passed.
JSON/HTML agreed on six Expert and ten Easy unique winners, no shared/incomplete/
invalid samples. Existing Expert warning remained. The sample is too small for
balance acceptance and is only output-path qualification.

Full Godot suite: 427735 assertions in 223.2s, exit 0, strict test log guard
passed. Four ERROR entries were verified as the intentional failed-save fixture
and three router-recovery failures. No arbitrary runtime error was accepted.
No source/test edits overlapped this full run. Full log SHA-256:
`4b0218885930ca6a4caff8fe5ddc7bbb338fd8d680920409415c6f47aef64672`.
No new server or real-network campaign is claimed in this reporting stage.

Final report-tool source fingerprint:
`cd39a5b2766c1d8c93e50e1824034ca2f4de306e014aa1ffdf67fddea13663bc`.
It changes because tools are fingerprinted, not because gameplay was retained.
No code/test edits overlapped the integration run.

Changed source/test SHA-256, matched between checkout and runtime:
- tools/balance_sim.gd: `479b0edbbc53dc41ffa0599214f17ebfabaccd2caa2ed68fc654f1245daf483b`
- tests/suites/test_balance_sim.gd: `7a057db568bbb9ac09635ca99796abfc8b36ef9eabc722d2d44b286f99450766`

Sibling `qualification-balance-outcomes-2026-10-15/` preserves tool logs and
synthetic integration reports/recount script, not private saves. No production
deployment, Git push/merge, fresh Archive, upload or Apple submission occurred.
Actual Tank Expert balance and device/release gates remain open.
