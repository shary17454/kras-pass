# Full Regression and Singular Leak Gate

Godot source: `5032001de241c75d57aa3143a12ed31f964d37a9`.
Runtime is the status preparation implementation documented separately at
`c377dfd62fa3e43c5b20acbaa124ab8185e5422e`.
Branch for this gate fix: `fix/kras-singular-object-leak-gate`, based on PR 107.
No runtime GDScript, scene or project configuration changed during either run.
No main integration, signed Archive, upload or Apple review occurred.

## Actual Full Runs

Both runs used Godot 4.7.1 headless, fixed FPS 60, separate external test save
directories and the complete `tests/test_runner.tscn`, without a suite filter.

| Run | Assertions | Exit | Duration | Exit Diagnostics |
| --- | ---: | ---: | ---: | --- |
| Ordinary | 365826 passed | 0 | 442.8 s | One ObjectDB instance leaked |
| Verbose | 365826 passed | 0 | 513.2 s | No leak warning emitted |

Ordinary console: `/tmp/kras-current-full-regression-5032001.stdout`.
Verbose console: `/tmp/kras-current-full-verbose-5032001.stdout`.
Engine logs use the same names with `.log` instead of `.stdout`.
The known sandbox system-CA error is separate from gameplay/test errors.

The ordinary run is not a clean shutdown result despite passed assertions and
exit zero. The verbose rerun did not reproduce the leak, so it did not identify
the leaked object and does not prove the intermittent issue was fixed.
Do not discard the less favorable run or describe the project as leak-free.

The integration suite exercises each registered minigame with four Bots and
short ordinary round windows, ranking, timeout, multi-round, pause/restart,
controller loss, difficulty comparisons, fantasy-world geometry and real
three-lap AI finishes across the race maps. The whole runner also covers saves,
replays, input, HUD, AI and network state/capture suites. This is not four humans
over Internet, all-game rendered QA, natural-round balance qualification,
physical FPS/heat/battery evidence, or a passing full CI/network matrix.

## Gate Reproduction and Correction

The old ObjectDB regex only recognized the plural `instances ... leaked`,
and accepted `WARNING: 1 ObjectDB instance was leaked at exit`.
A small positive-summary fixture `/tmp/kras-single-leak-fixture.log` reproduced
the false success before the correction (exit zero).

The checker now recognizes singular/plural forms with `was`, `were`, or neither.
Three wrapper regression cases cover the newly recognized forms.
`sh tests/check_party_wrapper.sh` passed its success path and 18 failure cases.
Evidence directory: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-wrapper-test.s9mSvj`.
The corrected checker rejects the ordinary full console (exit one) and accepts
the clean verbose console (exit zero). Checks must use captured console output:
the engine `.log` alone may not contain final exit cleanup diagnostics.
The existing `tools/check_party.sh` already checks `.stdout`.

`git diff --check` passed. A path-limited diff against `5032001` confirmed that
GDScripts, scenes and project settings are unchanged by this shell gate fix.
The 365826 result belongs to that Godot source, not a new runtime optimization.
Full runs took place before modifying the checker and wrapper tests.

## Remaining Gates

Investigate/reproduce the single intermittent exit leak, remaining rendered
stalls and startup latency; qualify balance, full CI and real local/online
sessions; complete physical iPhone/iPad and production acceptance. Current
App Store source/version/build validation, local Xcode 27 signed Archive,
signature/export validation, upload/processing and review submission remain
unperformed for this source. Xcode Cloud is not the intended release path.
