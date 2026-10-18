# Goal Guard Independent Difficulty Cohort

Source: b2861efb6d987e9942925ce820301143b3b0d014. Clean checkout,
runtime fingerprint 53cde46b50cf16a86a63439072b716dfbf475238dfca1ef42a671d5bc384b552
at simulation start and end. No gameplay, AI, threshold or test edits.

Godot headless fixed-fps 60, natural original-duration matches, runs=64,
only=goal_guard, seed-offset=8900000, isolated save directory. Process exit 0;
both stdout and engine log passed tools/check_godot_log.sh runtime checks.
Completed 64 baseline matches, 32 matched difficulty samples and two
mutator/chaos matches: 98 total, no clipping.

Independent report inspection checked all 16 paired seeds, character rotation,
alternating Expert slots, completed samples, finite scores and legal places.
Recalculated placement values: Expert 220, Easy 196, edge 0.5288461538461539.
Baseline winner slots: 15 / 11 / 21 / 17; zero ties; average duration
33.2940104166661 seconds. Both mutator/chaos checks completed successfully.

The previous 8000000 cohort on older 7681393 source reported edge
0.519230769230769 and a difficulty warning. The independent cohort has no
automated flags, but that does not erase the earlier warning or prove a strong
human-perceived difficulty progression. The metric is placement share, not
the probability that Expert wins. No arbitrary stat boost or threshold waiver
was made. Current all-game campaign 37950278256 remains pending.

Raw report, stdout and engine log:
../qualification-goal-guard-independent-890-2026-10-09/.
This is desktop simulation evidence, not physical iPhone/iPad performance,
production networking, all-map acceptance or App Review submission.
