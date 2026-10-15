# Balance Recheck History

Added `tools/balance-sample-index.mjs` as a read-only supplement to the existing
content audit. That audit stores the last supplied row per game; this index
retains every supplied sample and unions current-source warning flags.
It does not replace `tools/balance-report.mjs` campaign attestation or change
the Godot content audit, simulation, balance thresholds, or runtime behavior.

Usage:

```sh
node tools/balance-sample-index.mjs ROOT REPORT.json OTHER_REPORT.json
```

The CLI reads the real `data/minigames.json` catalogue and computes the expected
source fingerprint from the checkout, not from a report's assertion. Missing
evidence, malformed data, incomplete counts, stale or changed source, wrong
engine/mode/pairing, and contradictory flags/severity cannot silently become
clean current evidence. Eligibility uses the basic natural-sample contract;
it does not verify seed-pair details, stress objectives, CI run identity, or
device acceptance. Strict campaign attestation remains separately required.

Current warnings are retained even when another part of their sample is
incomplete. Old-source warnings remain visible on their sample but are not
relabeled as current-source results. Duplicate report labels, unknown games,
and duplicate game rows are rejected. Overlapping seed samples are not summed
into an invented independent match count. `releaseReady` and
`campaignAttestationVerified` always remain false; device review remains open.

## Actual Current Samples

Four candidate Crumble Court reports were indexed: 24 baseline runs at each
of offsets 1200000 and 1500000, and 96 baseline runs at each offset. The
expanded 1200000 sample retains `spawn slot advantage` while the other three
have no flags. The resulting review index keeps the warning and requires
balance review. No sample was discarded because its result was inconvenient.

Output and test evidence: `qa/platform-shortest-route-ties-2026-10-08/`:
`current-sample-index.json`, `sample-index-tests.log`,
`sample-index-server-full.log`.

Nine new tests cover warning order, stale/changed source, incomplete samples,
invalid fields, empty evidence, duplicate input, overlapping runs, actual CLI
catalogue/source pinning and malformed JSON. The combined focused tool suites
pass 92 tests. Full server suite passes 238 tests, zero skips/failures, using
six actual world captures from the current Godot gate. No public production
database or accounts were used. Node 24.18.0.

The runtime fingerprint before and after these MJS/test-only edits remains
`523906225b6ea660b7726e763b468fe4528b4d604e18bf9d28abe10926e338e3`.
The ongoing candidate campaign's catalogue job has completed successfully;
its 39 simulation jobs were queued at inspection. No running campaign was
cancelled. Local tool commits are not yet pushed to avoid restarting the
existing PR quality run. No release approval, merge to main, native archive,
Apple upload, processing or review submission occurred.
