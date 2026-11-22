# Pair-Balanced Measurement Contract

The ordinary balance-report path remains 24 baseline matches with adjacent
rotation. This change does not alter simulation physics, balance thresholds,
content readiness, CI policy, or existing evidence acceptance.

An explicit opt-in path accepts the existing tests/balance_pair_sim.tscn
measurement format through --pair-balanced-attestation=FILE, together with an
explicit current --source-fingerprint=SHA256. A campaign must use natural rounds,
the catalogue default arena and duration, and a multiple of 56 baseline matches.
Custom scenes, assets, presets, shortened windows and mixed roster policies are
not substitutes for that campaign.

## Provenance

Before execution, freeze a committed checkout and capture both the simulation
fingerprint and captureTestSchedule() output. Capture them again after execution.
The latter separately pins the pair simulator, schedule and report/source tools:
tests and .mjs files are not covered by the simulation fingerprint.

Seal each original parsed report using balanceReportDigest() and retain its
manifest independently of editable report artifacts. The manifest records commit,
run, seed offset, baseline count, simulation source, test schedule and game/report
digest mapping. An in-progress manifest may omit games not measured yet; partial
summaries cannot certify a complete campaign.

This is a trusted measurement record, not a cryptographic signature, independent
execution witness, archive attestation or recreation of Godot's random generator.
Never backfill a new manifest to qualify an older diagnostic report.

## Distribution And Limits

Each 56-match cycle must contain 28 appearances per character, seven per seat,
and 12 co-appearances for each character pair. Quartet seat rotation is checked,
not only aggregate totals. Seed sequences, mirrored Expert/Easy assignments,
completed counts, result metrics and original warning integrity are validated.

Difficulty matches total max(16, 2 * ceil(baseline_runs / 4)). Thus baseline counts
56, 112 and 224 require 28, 56 and 112 difficulty matches respectively, plus two
mutator completion checks. Only 224 of these three counts allocates difficulty
pairs equally across all eight characters. Allocation is not statistical power.

Expert edge is placement-point share, not outright win rate. The original Godot
p95 warnings are retained through the report digest, not recomputed with a
different JavaScript random generator. Do not lower thresholds or repeatedly
resample until a favorable result appears.

All summaries retain balanceReviewComplete=false and releaseReady=false.
Even a complete, warning-free measurement requires substantive balance review
and separate polish, gameplay, device and release qualification.
