# Keeper reachable threat selection

Parent: `9aae49a0084d6f23d099d04b6c1fd71f0348c243`.
Branch: `feature/kras-online-random-rotation`.

## Decision defect

With multiple visible incoming balls, high-prediction keepers selected the
earliest crossing even when personal movement could not possibly reach it.
They abandoned a later reachable save. Four goal directions reproduce this
without reading hidden ball velocity or changing movement rules.

High-prediction keepers now prefer the earliest reachable observed crossing.
The travel budget subtracts observation age and uses the keeper's own speed,
momentum and available dash meter. An optimistic upper bound preserves
marginal saves. When no reachable alternative exists, the previous incoming
threat remains the target. Low-prediction targeting is unchanged.

No speed, reaction delay, damage, scores, difficulty threshold or round rules
changed. This is a decision correction, not a secret advantage for bots.

## Focused verification

The final pre-fix fixture fails eight target-choice assertions (13 pass,
exit 1). Corrected expanded fixture passes 41 assertions, exit 0. It tests
all four directions, delayed observations, unavailable dash charge, personal
momentum, hidden threats, private-velocity independence and the fallback.
All 442 scripts compile. Full regression qualification is recorded below
after its process completes, not inferred from the focused suite.

The first complete-suite attempt was interrupted before its final summary.
After resuming, its process handle was missing and a local process check
found no matching Godot process. Its partial log is retained as
`../qualification-keeper-reachable-2026-10-09/full-interrupted.stdout` and is
not passing full-regression evidence. A fresh fixed-60-step attempt is
required; it does not change game duration, scoring or physics rules.

Logs: `/tmp/kras-keeper-reach-red-final.stdout`,
`/tmp/kras-keeper-reach-unit-final.stdout`, `/tmp/kras-reach-compile.stdout`.

## Natural Storm Heart campaigns

Each group contains 24 baseline matches, 16 matched-seed difficulty matches
and two mutator/chaos smoke matches. Rounds use their natural duration, not
clipped rounds. Runtime fingerprint, unchanged during all three campaigns:
`5f69293f7f8e7fa281c0fafc8e7d6a4165a7f070210b83074f88197c3506f716`.

| Seed offset | Expert share | Ties | Zero-score rounds | Flags |
| --- | ---: | ---: | ---: | --- |
| 5200000 | 0.524038461538462 | 0 | 0 | none |
| 5400000 | 0.533653846153846 | 0 | 0 | none |
| 5600000 | 0.538461538461538 | 0 | 0 | none |
| Goal Guard, 5400000 | 0.528846153846154 | 0 | 0 | none |
| Magnet Court, 5400000 | 0.538461538461538 | 0 | 0 | none |
| Sky Court, 5400000 | 0.533653846153846 | 0 | 0 | none |

The previous source's 5200000 group had expert share 0.519230769230769,
below the existing 0.52 threshold. That result remains historical evidence;
the threshold was not relaxed. Passing these finite groups is not proof of
universal balance or readiness of all 39 games.

Reports: `/tmp/kras-keeper-reach-storm520/report.json`,
`/tmp/kras-reach-storm540/report.json`, `/tmp/kras-reach-storm560/report.json`.

## Local multi-engine verification

`node server/network-smoke.js --game=storm_heart --humans=2`: exit 0,
PASS. Two real Godot peers and two bots agreed on scores `[13,16,15,19]`;
both peers reconnected. The guest received 1088 world snapshots. Both raw
peer stdout logs passed the runtime checker. Server loop maximum was 88 ms
with the full regression also running: not a latency/performance acceptance
measurement. The first sandboxed attempt failed to bind loopback (EPERM);
the authorized local loopback attempt passed. No production service used.

Peer evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-zUZ1wH/`.
Durable completed logs and campaign reports are copied to
`../qualification-keeper-reachable-2026-10-09/`.

## Release limits

Shared keeper variant campaigns and their log verification passed. Complete
regression still requires its terminal summary and log verification.
Physical-device performance/energy,
current-source all-game qualification, production backup/migration/deploy,
and a fresh exact-source local Xcode 27 Distribution archive remain release
gates. The old archive and App Store Connect build 107 are not this source.
No main merge, production operation, Apple upload, submission or withdrawal
is part of this correction.
