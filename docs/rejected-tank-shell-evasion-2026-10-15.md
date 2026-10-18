# Rejected tank shell-evasion candidate

Status: REJECTED_BALANCE_CANDIDATE. Stage 0 remains QA_PENDING / MERGE_PENDING.

## Hypothesis And Targeted Checks

The prior diagnostic found early armor eliminations despite Expert delivering
more damage. A candidate added lateral evasion of approaching visible shells.
It estimated velocity from delayed position observations, not live projectile
speed/direction or guidance targets. Hidden, occluded, expired and own shells
were excluded. Pooled relaunches reset observation credit. Escapes were rejected
near the arena rim or behind cover. No score, character, weapon or rule values
were changed.

The initial regression failed on the original code (missing feature). An early
candidate test failed four assertions because the fixture rewound its own clock;
separating the cases and sampling monotonically fixed the fixture, not a gameplay
threshold. The final safety suite passed 85 assertions including real collision
cover on all four difficulties. Existing tank perception/aim/steering checks
passed 415 assertions. Compile passed 461 scripts; strict guards passed.
These narrow successes were NOT sufficient for balance acceptance.

## Frozen Natural Comparison

Base commit: `105c1fb` on feature/kras-online-random-rotation.
The candidate changed tank_brain.gd and its test/runner only.
Gameplay fingerprint:
`c92bbb46453518f2c7461cd2cdc1142752587bdc3ba3716bb040280e43f27318`.
Candidate source SHA256:
`32c9965e7aae11b8adc5c7cdb1e4e62cb336cde8950b4e6321333d37f4bcb84a`.

Oasis, Godot 4.7.1, natural durations, fixed FPS 60, seed offset 96000000:
112 baseline matches, 56 completed difficulty comparisons and two successful
mutator/chaos matches. Source fingerprints matched before and after execution;
baseline seeds/rosters exactly matched the reference. No source edits or other
campaigns overlapped this run. Exit 0, runtime log guard passed, isolated
profile/backup/settings MD5 checksums and schema 2 verified.

| Metric | Original ordinary | Ordinary repeat | Candidate |
| --- | --- | --- | --- |
| Seat wins | 40/14/37/21 | 41/13/37/21 | 48/16/23/25 |
| Slot bias | 0.1071428571 | about 0.116 | 0.1785714286 |
| Expert point share | 0.4267857143 | 0.4285714286 | 0.4196428571 |
| Average simulated duration | 16.379464 s | 16.380655 s | 15.636607 s |

Both original balance warnings persisted. The candidate failed to improve
Expert and increased the observed slot bias. Reject it rather than adjusting
scoring, thresholds or the seed cohort to pass. No held-out acceptance or other
map qualification is claimed for this rejected candidate.

Wall time was 1240.9 seconds, substantially slower than previous runs, although
average simulated rounds did not grow. At one observation the owned process
had about 101 MiB RSS and 32.2% CPU, and the Data volume had 54 GiB free. These
single observations do not explain the slowdown, prove absence of memory leaks,
or establish phone performance. The diagnostic PID request initially hit an
approval-review timeout; one permitted retry succeeded. The campaign was not
restarted on that timeout.

## Restoration And Evidence

Only our candidate additions were removed. tank_brain.gd and test_runner.gd
returned byte-for-byte to HEAD; the candidate-only suite was removed from the
active tree. The existing passive elimination diagnostic remains. The isolated
runtime was also restored; gameplay fingerprint returned to
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
Restoration compile passed 460 scripts. The existing tank suite passed 415
assertions in 18.1 seconds. Both exited 0 and passed their strict log guards.
The full suite was not rerun for this discarded candidate; no new whole-product
acceptance is claimed from these targeted restoration checks.

Outside Git: ../qualification-tank-shell-candidate-2026-10-15/ contains the
rejected source, suite, runner, patch, all attempted test logs, compile log,
runtime log and final report. No save settings/secrets were copied.
Report SHA256:
`b5750c109b8d45298e4e3e8e21a0d1bfd2eba284f0f00d7147bb1c042e52bec2`.

Next: investigate exposure and target/route selection in the natural survival
game before another behavior change. The original tank balance, whole-product
QA, device acceptance and release gates remain open. No main push, Railway
operation, archive, Apple upload or review submission occurred.
