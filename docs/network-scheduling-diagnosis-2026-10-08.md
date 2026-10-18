# Network scheduling diagnosis and current-source campaign

Code: `b8efc5131ea3b47b4c20dabdb04463414e1b7264`.
Parent: `3869e4ad114daf951fe5bc0c421e4a76446366b7` (PR 207).
Only smoke diagnostics and their tests changed. No gameplay, authority,
network protocol, production configuration, AI profile or acceptance threshold
changed. The server's production entry point does not start this probe.

## Diagnostic addition

`--scheduling-probe` optionally starts a separate Node process with a bounded
100 ms timing monitor. Each monitor retains at most 50 stalls and the worst
later stall, including process CPU and monotonic time-origin epoch intervals.
Correlating intervals can distinguish a server-local event from simultaneous
cross-process delay; overlap alone still does not establish a root cause.
Only timing, operation names and room phases are recorded, not payloads,
room codes, account data or credentials. Probe response failures still execute
the smoke runner's client/server cleanup. The child is killed and its close
awaited when stopping. The feature is off unless explicitly selected.

Focused timing/probe tests: five passed. Full server suite: 205 passed,
zero failed/cancelled/skipped, using the six actual world captures from the
PR 207 candidate gate at `kras-party-check.aebtpa/saves-tests`.
The Godot runtime and capture schemas are byte-unchanged from that source.
Log: `/tmp/kras-network-probe-server-tests.log`.

## Two measured four-client runs

Same source, Scrap Karts, four actual local Godot clients, seed 309019:

| Run | Scores agreed by all clients | Host/guest reconnect | Guest world snapshots | Maximum server loop delay |
| --- | --- | --- | --- | --- |
| First | 14,24,10,16 | passed | 1388,1388,1369 | 26 ms |
| Repeat | 12,6,16,31 | passed | 1592,1611,1611 | 38 ms |

Both server and independent monitor retained zero stalls and null worst-stall
values. All eight engine stdout guards passed. The original monitor threshold
was not relaxed. Distinct results between real-time input runs with the same
seed do not prove deterministic replay; agreement within each run is verified.

Evidence under the macOS temporary root:
`kras-network-smoke-GJYSuy`, `kras-network-smoke-vWXAZ7`.
Logs: `/tmp/kras-network-correlated-2026-10-08.log` and
`/tmp/kras-network-correlated-repeat-2026-10-08.log`.
Raw bounded timing reports: `docs/qa/network-scheduling-2026-10-08/`.

Earlier delays of 455 and 608 ms remain retained in PR 207. They were NOT
reproduced in these two measured runs, so neither correlation nor a cause was
established. Do not claim the intermittent issue is repaired or solely caused
by the other owned tests. This is localhost acceptance, not Internet,
production smoothness, phone FPS, battery, thermal or sustained soak evidence.

## Campaign progress and exact-source limits

Old campaign 37694780646 remained live on
`82f3a7692b8f61b341fb26d69b3170c3a82496cd`. Its 34 downloaded artifacts
validate as 1428 natural matches, with five games missing:
sabaq_sawarikh, tag_hunt, base_siege, drift_floes, duo_clash.
All 34 start/end fingerprints match
`d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e`,
engine `4.7.1-stable (official)`.

The four bosses retain explicit seeded objective outcomes, not score-based
inferences. Baseline defeats/survivals: Colossus 22/2; Dreadnought, Forge and
Sovereign each 24/0. All four paired difficulty cohorts record 16 defeats;
both stress cohorts for each record survival rather than boss defeat. Those
are valid completed rounds but NOT stress boss victories. Crumble seat,
Magnet seat and Scrap difficulty warnings remain in this OLD-source sample.
Six newly downloaded raw game reports and the partial summary are retained
alongside the timing evidence; the whole download is in
`/tmp/kras-campaign-37694780646-followup-28` (now contains 34 artifacts).

New campaign: https://github.com/shary17454/kras-pass/actions/runs/37709226998
Branch `test/kras-network-scheduling-probe`, exact source
`b8efc5131ea3b47b4c20dabdb04463414e1b7264`, offset 1200000.
Dispatch and head SHA were verified live. Its catalogue job is queued at this
checkpoint; no new-game completion is claimed. This campaign is necessary
because the earlier campaign lacks the Magnet and Scrap fixes. Neither was
cancelled/restarted due to quiet output. It uses the existing verified Godot
4.7.1, 24 baseline/16 mirrored/two stress policy and three-job concurrency.
These are GitHub game tests, NOT an Xcode Cloud archive or upload.

## Uncompleted objective

Current all-game balance/perception/polish qualification, the intermittent
timing diagnosis, physical iPhone/iPad QA and performance, approved production
backup/migration/source promotion/rollout and Internet/auth acceptance remain.
A fresh exact-source local Xcode 27 Distribution archive, signature validation,
upload, processing and separate App Review submission have not been performed
for this source. No merge to main, production operation or Apple action occurs
as part of this diagnostic change.
