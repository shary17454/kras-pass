# Team outcome diagnostics

The balance simulator now captures authoritative controller team scores before
teardown, separate from individual MatchResult placements. Each team baseline
sample records its seed, team totals, winning teams and competitive draw state.
The report adds team_outcomes, team_draw_runs and team_unknown_runs.

The existing individual tie_rate, flags and acceptance thresholds are unchanged.
No product/controller, tournament scoring, network message, input, character
stat or result persistence schema was changed. Diagnostic metadata is attached
only by the simulator after the match completion callback.

Unsupported controllers, a missing opposing team, inconsistent shared totals
or invalid scores return an unknown outcome, not a successful no-draw result.
An unknown count must be reviewed; these fields are supplementary diagnostics,
not a new replacement release validator. The simulator's natural configs use
one round, so the captured totals describe the complete sampled round.

Natural Duo Clash sample, seed offset 4400000: 24/24 baseline matches,
16/16 mirrored difficulty matches, both stress variants completed. All 24
team outcomes were known and there were zero opposing-team draws. Individual
co-first placement occurred in 5/24 matches (tie_rate 0.208333333333333).
This proves why the two metrics must be distinct for this sample; it does not
reclassify the older 4200000 sample's 50% individual tie warning.

Start/end simulation source fingerprint matched:
c26bfb4796188c08cf64012e0eb7a24f4b76b755e7bff194a7d5868997283de2.
Natural runtime log guard passed, and all 430 scripts compiled.
An independent Node check recomputed the draw boolean from every recorded
team-score dictionary and matched all 24 samples.

Unit cases cover both possible winning sides, equal opposing totals,
individual co-winners, a missing opposing side, fractional scores and an
unsupported controller. Raw logs/report are retained outside the checkout:
../qualification-team-outcome-2026-10-08/.

Development failures are preserved, not counted as acceptance: the initial
full run had one failed fixture because Duo Clash's typed int return coerces
the artificial fractional input before the validator sees it. A dedicated
untyped fake controller now tests the actual invalid-return contract. Its
initial variable name also collided with an existing loop variable; the
parse-failed run was stopped and the fixture renamed. The final focused run
passes 587 assertions. No gameplay rule was changed to satisfy these tests.

Final full regression: exit 0, 392731 assertions, 232.0 seconds; strict test-log
guard passed. The longer wall time is not a device-performance measurement.
Production promotion,
physical-device QA, remaining gameplay balance and local Xcode/App Review
release gates are still open. This is not a claim that all requested work ended.
