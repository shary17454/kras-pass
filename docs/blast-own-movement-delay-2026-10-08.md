# Blast Ball own movement-delay budget

Fighter ignores steering while its own stun or freeze timer remains positive.
Blast Ball planning previously reserved approach/escape time as if steering were
available immediately. It now also reserves max(own stun, own freeze, 0), since
the timers expire concurrently. These are the controlled player's own status
timers, not hidden rival state or private ball momentum.

Only the approach viability condition changed. Movement speed, freeze/stun
durations, character stats, reaction policy, visible fuse sampling, RNG policy,
game scoring and balance acceptance thresholds were not changed.

Regression: RED 381 assertions passed and two failed for frozen/stunned approach
planning. GREEN 388 assertions passed, including a marginal short freeze,
overlapping timers, unchanged real status timers and restored offensive contact
when movement is available. All 430 scripts compile. Strict natural runtime
log guard passed.

Natural seed cohort 4200000 completed 24 baseline matches, 16 mirrored
difficulty matches and both stress variants. Start/end fingerprint matched
8e106c3b9d7799a34f15146b17542833f056f79475f9b7e9ec2c29596ce10a79.
The expert point share is 0.45 and the expert/easy warning remains. This repair
is not evidence that the wider difficulty-balance problem is resolved, and
does not justify promotion to READY or removal of the warning.

Raw RED/GREEN, compile, natural reports and final regression evidence are
retained outside the repository in ../qualification-blast-immobility-2026-10-08/.
Independent cohort 4300000 also completed 24 baseline, 16 mirrored and two
stress matches with the same stable source fingerprint and a passing strict
log guard. Its expert share is 0.50625 and retains the difficulty warning.
Recomputing 4-3-2-1 placement points across both cohorts gives expert 153/320
(0.478125), not a positive difficulty qualification. Total natural matches: 84.
Full regression: exit 0, 392738 assertions, 194.2 seconds, strict test-log guard
passed. This is not physical-device performance or battery evidence.
No production deploy, Archive, upload or App Review submission was performed.
