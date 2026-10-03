# Boss objective evidence across sample families

## Source

Implementation commit: `86233b9264ae7cfb9905020756e0d4f7986b2ce5`.
Branch: `feature/kras-boss-outcomes-all-samples`, based on PR #25.
All 379 tracked Godot/data input files selected by extension matched the owned
runtime checkout byte-for-byte before the natural simulation. This warm test
checkout is not a clean iOS release archive or proof of export provenance.

## Changes

- Difficulty samples retain the configured seed, character, expert seat pair,
  completion flag, and explicit boss outcome.
- Mutator and chaos smoke records retain separate boss outcomes. A natural
  deadline is recorded as survived, not as defeated.
- Missing, malformed, or unknown difficulty/smoke objectives block tool
  qualification. Results from a different minigame cannot prove the selected
  boss objective; retained aggregate rounds must have matching identities.
- The shared JavaScript validator and per-game CI coverage check reject
  missing comparison evidence. Campaign summaries include boss comparison
  counts without asserting release readiness.
- Seed parsing checks significant digit length before integer conversion,
  eliminating the oversized integer diagnostic while retaining leading-zero
  valid inputs and the existing 0..1000000000 limit.

## Executed checks

- Godot 4.7.1 policy suite: 449 assertions passed.
- Compilation: all 324 scripts compiled.
- Balance report tests: all 59 passed.
- Server suite: 179 tests, 173 passed, six skipped, zero failed.
- YAML parse, byte comparison, log guard, and diff whitespace checks passed.
- Initial sandbox invocation failed to open the engine's default user log and
  crashed before tests. A local-system invocation passed; subsequent sandbox
  runs used explicit temporary engine log paths and passed too. The final
  compilation/simulation logs still contain the macOS sandbox CA lookup
  diagnostic, which is not evidence of production TLS failure or success.
- The harness deliberately probes two empty suites and prints their expected
  failure messages; the parent regression suite verifies those failures and
  its final 449-assertion result is successful.

## Actual natural simulation

Command (owned warm runtime checkout):

```sh
godot --headless --fixed-fps 60 --path . \
  --log-file /tmp/kras-boss-all-outcomes-natural-engine.log tools/balance_sim.tscn \
  -- --runs=2 --only=boss_forge --seed-offset=400000 \
  --out-dir=/tmp/kras-boss-all-outcomes-natural-report \
  --test-data-dir=/tmp/kras-boss-all-outcomes-natural-save
```

Terminal exit zero, wall duration 218.7 seconds. The baseline and difficulty
samples use the natural round window, not `--clipped-rounds`. The two stress
samples intentionally retain the tool's short smoke window and are not natural
balance measurements despite sharing a report labelled natural.

- Baseline: two completed matches, two boss defeats, zero unknown outcomes.
- Difficulty: 16 completed matches, 16 boss defeats; mirrored seeds and all
  eight characters retained in the raw report.
- Mutator and chaos: completed, explicit survived outcomes, no unknowns.
- Baseline average simulated duration: 64.375 seconds.
- Expert share: approximately 0.676829.
- Existing game and smoke flags: empty. Two baseline matches are insufficient
  to certify character or spawn balance; thresholds were not relaxed.

Raw generated report: `boss-all-samples-natural-forge-86233b9.json`.
Both exported objective validators accepted this report, and the runtime log
guard rejected no script failure, leaked object, or incomplete result marker.

## Other gates observed, not completed

The macOS system session still has the existing requested Apple Distribution
identity and Apple Development identity. No P12 import, password request, new
certificate, or revocation was performed. Apple Developer's existing browser
tab remains at sign-in, so refreshing the existing device development profile
still needs the user's authenticated session.

Main Game Quality run `37139354043`, source
`88dafac8ed88ec56f96636fb5b1ccdc5b9d3a1c6`, was observed with eight successful
jobs, one skipped, three in progress, and 29 queued. This is not final CI
qualification and does not test this feature branch's implementation.

Remaining: natural objective campaigns for all four bosses at the full sample
count, investigation of the 11 independent campaign balance signals, complete
current-source online qualification, physical iPhone QA, fresh release source
and version/build verification, signed archive validation, upload, processing,
and actual review submission. Production online remains disabled.
