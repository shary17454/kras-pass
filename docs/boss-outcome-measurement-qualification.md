# Boss Outcome Measurement

Implementation: `f1848efd22ab696fbc2c23cce56f094f3f46816c`.
Base: PR 23, `a881b2e726d3188a05f2bc69e726a07cb89889ee`.

## Measurement

Natural or clipped balance reports now retain each baseline boss seed and an explicit `defeated`, `survived` or `unknown` outcome, plus separate counts. Score, placement, duration and completion alone are never interpreted as boss defeat.

The classifier requires completed results, valid integer round counters and agreement between all player detail rows. Aggregate counters must agree with retained leaf-round evidence. Missing, malformed, contradictory or interrupted evidence is unknown, not a win. Unknown baseline outcomes block qualification; a complete sample with no defeated boss receives a balance-review signal. Existing duration, bias and Expert thresholds remain unchanged.

This change does not add explicit objective outcomes to the difficulty or mutator sample records, and the external JavaScript report aggregator has not yet gained a strict boss-outcome schema. Those extensions remain open; do not infer full boss qualification from campaign execution success.

## Tests

- Policy suite: 374 assertions passed, exit 0, including missing evidence, survival, defeat, mixed rounds, contradictory aggregates and malformed detail types.
- Compile: 324 scripts passed, exit 0.
- All 718 tracked runtime inputs byte-matched the implementation checkout before the instrument smoke.
- Whitespace check passed.

Logs: `/tmp/kras-boss-outcome-policy-fixed.log`, `/tmp/kras-boss-outcome-compile.log`.

Initial policy attempts had a GDScript parse error from a null fallback passed to an int-inferred parameter. Those executions are not passing evidence despite the runner reporting one assertion and exit zero. The final classifier uses dictionary lookup, compiles and runs all 374 assertions. The runner's misleading result on a runtime suite abort remains a separate test-infrastructure issue; always examine engine errors and assertion coverage.

The sandboxed engine logged a system CA lookup diagnostic. The existing out-of-range seed test also emitted an integer conversion diagnostic before rejecting input; rejecting oversized values before conversion remains open. Neither is treated as proof of production TLS or authentication.

## Instrument Smoke

Actual command: Godot 4.7.1 headless, fixed FPS 60, `tools/balance_sim.tscn -- --only=boss_forge --runs=2 --clipped-rounds --seed-offset=300000`.

Completed 20 matches: two baseline, 16 mirrored difficulty, two mutator/chaos smoke. Exit 0, wall time 470.8 seconds. Report mode is explicitly clipped, baseline window 75 seconds. Baseline seeds 309001 and 309614 both recorded defeated; survived=0, unknown=0. Mutator and chaos smoke passed.

Raw artifact: `boss-outcome-instrument-smoke-f1848ef.json`; log `/tmp/kras-boss-outcome-instrument-smoke.log`.

This small clipped sample verifies actual instrumentation only. It is not a 24-run natural balance campaign, population evidence, other-boss qualification, physical-device performance or online acceptance. Natural campaigns must be re-run from the intended release source with the new objective measurement.

No production gameplay values or save schemas were modified by this branch. No main merge, Railway deployment, Archive, signing, upload or Apple review submission occurred.
