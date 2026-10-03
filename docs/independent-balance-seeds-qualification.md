# Independent seeded balance campaigns

Source change: `88a69d9bd14ea503699f027b1a0d79576a201d9a`, stacked on the
carved-ground candidate `c27ef9d002c6378b6baac5fc1f9ea6fd183b0317`.

## Purpose and policy

Repeating the same eight mirrored difficulty seed pairs cannot independently
confirm balance. The simulator now accepts `--seed-offset=N` (integer 0 through
1000000000). Zero preserves existing seeds. Independent runs use documented,
separated offsets such as 100000 and 200000, not undocumented rerolls selected
for favorable outcomes.

The offset applies to all baseline, paired difficulty and mutator/chaos seeds.
Each Expert/Easy pair retains the same character and actual seed while seats
are mirrored. Reports retain baseline and difficulty seeds plus both smoke
seeds. Gameplay rules, durations, AI parameters and review thresholds are not
changed by this validation feature.

The aggregator rejects mismatched source/report/game offsets, replayed baseline
or paired seeds, missing smoke seed evidence and invalid offset ranges. Existing
zero-offset artifacts remain readable as historical evidence; an independent
campaign must explicitly prove its offset everywhere. Reports with warnings
still need review, and complete coverage never implies release readiness.

## Tests and actual execution

- Godot simulator policy: 360 assertions pass, exit 0.
- Node campaign-evidence tests: 38/38 pass, zero skipped.
- All 324 scripts compile; Git whitespace check passes.
- YAML syntax and simulation environment seed wiring pass. This is not an
  actionlint or completed GitHub campaign claim; actionlint is unavailable.
- Actual invalid CLI offset -1 exits 2 before running matches.
- Historical paired campaign 37113379841 at c97cd88e88e9e957120d49027a33494828cb392e
  still aggregates 39 games / 1638 matches / 13 review games, paired verified,
  releaseReady false; warnings were not discarded by the new reader.
- Final actual Quick Draw instrument smoke at offset 200000 completes 20 natural
  matches: 2 baseline, 16 mirrored difficulty and 2 mutator matches, exit 0.
  Baseline seeds are 209001 and 209614; difficulty pairs begin at 204242 with
  step 97; mutator/chaos seeds are 205501/205502. Both smoke checks pass, flags
  are empty. This small instrument check is NOT a 24-baseline campaign or a
  balance approval for 39 games. Complete generated report is retained in
  `independent-balance-draw-smoke.json`.
- An earlier instrument run at offset 100000 also completed 20 matches but
  predates the smoke-seed metadata addition; it is not the final-source report.
- 717 tracked source/data/test/tool/server/project files match the runtime
  clone byte-for-byte; generated caches and docs are excluded from that check.

Logs: `/tmp/kras-independent-policy.log`, `/tmp/kras-independent-report-tests.log`,
`/tmp/kras-independent-compile.log`, `/tmp/kras-independent-invalid.log`,
`/tmp/kras-independent-draw-final.log`,
`/tmp/kras-independent-legacy-summary.json`.

## Full 39-game campaign

`balance-campaign.yml` dispatch/call accepts string input `seed_offset`. It
passes this via quoted environment variables to the simulator, coverage check,
source metadata and strict summary. It retains 24 baseline + 16 paired + 2 smoke
matches per game (1638 total), finite watchdogs and all existing requirements.

Dispatch from the committed feature source with seed_offset=100000 after push.
Record its actual run ID and terminal result separately. Queuing a run does not
prove match completion, balance, physical-device performance, production online
readiness or any Apple release gate. No main merge or Apple submission is
performed by this change.
