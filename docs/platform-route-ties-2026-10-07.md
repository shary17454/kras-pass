# Seeded Platform Route Ties

Base: 4b9f67b1f2b081ceee0b39c4be744c54e300c54a (PR 152).
Runtime: 9813f1574fca5678dec50ced8ff710e216253750.
Branch: fix/kras-platform-seeded-route-ties. No main merge or deployment.

## Correction

Equal tile scores previously retained the first BFS/dictionary candidate.
In a symmetric two-exit fixture, all 128 seeds in each of four seats chose
the first exit. Equal best visible first steps now use the player's seeded
generator. Multiple equally good destinations behind one first step count
only once. A unique best step consumes no additional RNG. This follows the
existing nearest-rival tie pattern; no stat, scoring, duration, visibility,
reaction delay or terrain rule changes. This corrects an observable route
tie bias, not a proven root cause of overall spawn-win disparity.

## Tests

Identical final fixture: 1067 pass, four failures before correction (all
seat distributions [128,0]); 1071 pass afterward. It verifies cardinal route
validity, reproducibility per seed/seat, both exits over 128 seeds in each
seat, exclusion of a hidden exit, and no RNG consumption for a unique route.
Previous hole/edge/contact/arrival/rescue tests remain passing.

AI visibility and four-tier warning delay: 3997 pass. All 398 scripts compile.
Strict log guards and git diff --check passed. Logs:
`/tmp/kras-platform-ties-{red,green,visibility,compile}.log`.
The 371732 full assertions, 204 server tests and all-39 stability cycle in
platform-warning-delay-2026-10-07.md belong to the parent runtime, not this
new tie correction. A final integrated-source gate is still required.

## Natural Evidence

Each offset ran 24 baseline, 16 matched-character difficulty and two stress
matches, all naturally, without shortened clocks or forced winners.

| Offset | Expert score share | Slot bias | Character bias | Mean duration | Flags |
| --- | --- | --- | --- | --- | --- |
| 600000 | .54375 | .208333 | .083333 | 11.8806 s | none |
| 900000 | .6125 | .083333 | .083333 | 11.8813 s | none |

All game rows for 600000 are exactly equal to the parent warning-delay
sample, not merely similar averages. Thus this change does NOT demonstrate
improved spawn balance in that sample. Variation between offsets must not be
attributed to the code correction. Short round pacing and independent larger
balance review remain open; neither game nor all-39 READY is certified.

Reports: platform-route-ties-natural-{600000,900000}.json.
Logs: `/tmp/kras-platform-ties-{natural,independent}.log`.
Both start=end runtime fingerprints:
`5b543fddad46085c8def4fa8364510d63db43600ed0d63233c6e7afceb3e0f4d`.
Both stress cases pass in each report. These exact runtime files were measured
before their commit, without runtime edits during either run.

## Completed CI Reports

Run 37549144464 now has four completed game reports (plus catalogue), one
simulation running and 34 queued at the observed snapshot. Immutable source
3c4bbdb6d7437803cd53bba3e721b872ebb4675f predates the subsequent AI fixes.
Each downloaded artifact's balance-source.json, matching game ID, 24+16+2
natural completion, stable runtime fingerprint and two passing stress cases
were checked. All four reports have zero flags in their sample.

| Game | Expert share | Slot bias | Character bias | Mean duration |
| --- | --- | --- | --- | --- |
| ring_rumble | .583851 | .041667 | .083333 | 44.3993 s |
| crumble_court | .575 | .208333 | .041667 | 12.3174 s |
| tank_arena | .575 | .07 | .035 | 102.0417 s |
| bumper_bowl | .674847 | .166667 | .041667 | 85.0194 s |

Evidence: `/tmp/kras-hud-campaign-wave2`.
Reports: hud-campaign-{crumble_court,tank_arena,bumper_bowl}-natural-900000.json;
Ring report retained as hud-campaign-ring-natural-900000.json.
These are source-specific samples, not current-source/all-39 acceptance.

## Local Network Measurement

Four real scripted Godot processes, Crumble Court, seed 909001, completed
on a localhost WebSocket server. Host and guest reconnect passed; all peers
agreed on [4,8,12,16], guest world snapshots 700, 681 and 700. Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-JYMScc`.
The fixture overrides round duration to 15 seconds; it is network transport
and presentation acceptance, not a natural balance or Internet session.

Maximum event-loop delay was 251 ms. server-timing.json recorded a 230.08 ms
stall delay over 330.08 ms elapsed with 1.609 ms process CPU. This suggests
scheduling contention as a possibility, not a proven cause or a latency fix.
Retain this measurement even if a repeat is faster; no smoothness claim.

The repeat after all owned load checks completed also passed with the same
agreed results, host/guest reconnect and guest world counts 681, 700 and 700.
Maximum loop delay was 35 ms. Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-JeJijg`.
The difference is evidence of variable latency in this local setup, not proof
that a server defect was fixed or that production/phone latency is acceptable.

## Release Gates

Physical gameplay/FPS/thermal/battery/controller QA and installation approval,
all-game balance/perception/polish, final source promotion and regression,
approved production backup/restore/migration and protocol rollout, native
Apple auth/API/Internet acceptance, valid ASC session and fresh version/build,
new local Xcode 27 Distribution Archive/signature, upload, processing and
separate submission remain required. No old unsigned pack was relabelled,
certificate imported/created/revoked, main merged or production changed.
