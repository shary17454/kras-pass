# Blast Ball escape forecast separation

Radial escape used the interception forecast. A fast incoming ball's forecast
could cross the controlled player before the ball did, reversing the escape
direction toward the threat. Escape now advances the delayed visible position
only by its observed sample age (bounded to 0.35 seconds and scaled by the
existing prediction parameter). Offensive interception retains its original
lead. This is an estimate, not access to authoritative live ball momentum.

No physics, character stats, reaction delays, scoring, RNG or balance acceptance
thresholds changed. Regression covers incoming/crossed cues, sample age, zero
prediction and independence from private live momentum.

RED: 388 assertions passed, one failed. Final focused GREEN: 393 assertions.
Full regression: 392743 assertions passed, exit 0, 189.2 seconds. All 430 scripts
compile. Strict full-test and natural runtime log guards passed. The macOS
system-CA lookup warning is present; these results do not establish native
authentication, physical-device performance or battery acceptance.

Natural cohort 4200000: 24 baseline, 16 mirrored difficulty and two stress
matches completed. Expert placement-point share: 0.53125; flags: none.
Stable start/end simulation fingerprint:
60f1593289845db427c28f101db97776b0848643f427edcb32caf276c606bb7e.
One cohort alone does not establish broad balance readiness.

Independent fixed-step cohort 4300000 also completed all 42 matches, with the
same start/end fingerprint and a passing strict runtime guard. Expert share
is 0.525; flags: none. Across both mirrored cohorts the expert share is
0.528125 (169/320 placement points). Total natural matches: 84. This supports
the targeted escape repair under these seeds; it does not prove fairness for
all characters/maps/seeds or qualify the other 38 games.

Raw logs and reports are retained in
../qualification-blast-escape-forecast-2026-10-08/.
The first second-cohort invocation omitted --fixed-fps 60 and was deliberately
stopped (exit 130); it is not qualification evidence. The replacement uses the
same fixed-step configuration as cohort 4200000.

No production deployment, Archive, upload or App Review submission occurred.
