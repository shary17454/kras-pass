# Strict balance simulation arguments

## Problem and repair

The runner silently ignored unknown options, including a mistyped `--out`,
and silently converted/clamped malformed `--runs` values. This could start
the wrong cohort or write to a different output location while reporting
successful execution. The parser now validates an explicit argument vector
and applies configuration only after all arguments are accepted.

Supported options: `--runs=2..10000`, `--only=ID`, `--out-dir=PATH`,
`--seed-offset=0..1000000000`, `--clipped-rounds`, and SaveSystem's
`--test-data-dir=PATH`. Unknown/duplicate options, empty game/output values,
malformed numeric values and integer overflow are rejected. Save isolation
remains checked by SaveSystem and the existing runner before parsing.

Compatibility boundary: counts previously clamped to two now fail rather
than silently selecting a different cohort; counts above 10000 also fail.
Existing CI uses 24 and retains its exact arguments. A 1000-match count is
accepted by the parser; this does not claim 1000 matches were simulated here.
No product gameplay, scoring or balance thresholds were changed.

## Evidence

- RED policy test: 551 passed, one failed for the missing explicit-vector API.
- GREEN policy suite: 578 assertions passed; invalid requests preserve all
  prior configuration fields. Valid CI-style and clipped-mode requests pass.
- Contact-probe regression: 17 assertions passed.
- CLI negative test: typo `--out` exits 2 with an argument error; intended
  output directory was absent before and after, with no matches started.
- Positive natural Blast Ball CLI: 24 baseline, 16 paired and two stress
  matches completed, exit 0, 28.8 seconds. Actual output path matched
  `--out-dir`. Start/end fingerprint both
  `1487a081d4ee6b97b965948a66777317f2ceade1e78c54155b419382cbacd3bd`.
- The positive report's complete `games` and `mutator_smoke` arrays are
  deep-equal to the retained pre-change local diagnostic report at
  `../qualification-blast-exposure-4200000/report.json`. This is sample-specific
  compatibility evidence, not equivalence across every game/platform.
- Compile: all 430 scripts, exit 0.
- Strict positive policy, natural-simulation and compile log guards passed;
  the expected CLI rejection is intentionally an error, not a clean run.
- `git diff --check`: passed.

Logs/report: `../qualification-balance-args-2026-10-08/` relative to the
repository parent. Full project regression has not been rerun after this
tool-only repair; the previous 392655 result is from the ring repair, not
this changed source.

## Release gates remain open

Blast Ball still has `expert bots no better than easy`, expert share 0.475.
The GitHub campaigns still target `78d11ab`, not this source. No final-source
all-game acceptance, device QA, production deployment, archive, upload or
App Review submission is established by these checks.
