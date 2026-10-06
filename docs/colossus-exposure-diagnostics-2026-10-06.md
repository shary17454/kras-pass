# Colossus Exposure Diagnostics

Base runtime: PR117 `a23e0fba416d1d33d273a88d2c54fa35d0246ba1`.
Branch: `test/kras-colossus-exposure-diagnostics`.
Only the development probe changes; production scripts, data and rules are
byte-identical to the base. Existing runtime qualification is not a new
full-suite qualification of this changed test tool.

## Instrumentation

`tests/colossus_ai_check.gd --trace` now emits one COLOSSUS_WINDOW JSON array
per arm exposure, with per-slot active, geometric reach, safe-ground reach,
control-ready reach, visible/delayed cue, authored danger, deliberate AI lapse,
plan validity, attack-input, swing, cooldown and landed-hit measurements.
Observations do not publish inputs or mutate fighter/controller state. Reads
of internal AI/timer state are diagnostic-only, never supplied to AI decisions.
The probe excludes frozen ENDING/result-screen ticks and records a lethal
last-frame hit before teardown. Otherwise the old trace could overcount its
last exposure while the scene was waiting to show results.

## Matched Failed Baseline

Seed609614, medium difficulty, characters sakhra/fanoos/ramla/barq is the exact
second baseline configuration of the 24-run campaign (roster rotation1).
Twenty-four exposure windows were observed. Thirteen player/window samples
had at least20 control-ready, safe-reach physics observations (0.333 seconds
at60Hz); six of these had no landed hit and no attack input. Five had no
authored warning overlap while ready. All five had a valid delayed-visible
attack plan during those ready observations. Deliberate lapse accounted for
16/30, 15/29, 21/30, 2/48 and 36/37 ready ticks respectively.
This narrows the investigation to timing, decision sampling and willingness,
not simply navigation or invisible weak points. It does not prove that every
miss has the same cause or that any particular tuning would improve balance.

The instrumented and uninstrumented runs have identical final summaries:
boss not defeated, health250, scores[55,220,165,110]. Both probes correctly
exit1 for an actual failed boss defeat, not an infrastructure error. The
stdout runtime guards pass. This must not be reported as a passing boss test.
Evidence:
- `/tmp/kras-colossus-window-plan.stdout` and `.log`.
- `/tmp/kras-colossus-window-control.stdout` and `.log`.

A first exploratory trace used mowja instead of barq and defeated the boss.
That was NOT the matched failed baseline and cannot establish an improvement.
Its initial reach-only counters also included falling/stunned and ending
states; those misleading counters were replaced before the final matched run.

Final compile: all392 scripts pass. `git diff --check` passes.
`/tmp/kras-colossus-window-final-compile.stdout`.
The next controlled balance experiment must retain the same health/damage
rules across humans and bots, measure a second seed cohort, and inspect both
defeat rate and character contribution. No global AI buff or artificial
successful result has been introduced. Boss readiness remains NEEDS_BALANCE.

PR117 CI was observed queued at run37475055714, head a23e0fb. It is not a
verified pass for this test-only branch. No main merge, Railway deployment,
signed archive, Apple upload or review submission occurred. Final iOS work
continues to require local Xcode27, not Xcode Cloud.
