# Turret Start Heading Qualification

Base source: 9d528df. Campaign 37915371500 at b61e4b4 had 14 completed
game reports (588 natural matches) at this observation. Its qualified
partial reports raised `spawn slot advantage` for turret_duel and
`expert bots no better than easy` for scrap_karts. The latter is still open.
The all-game campaign remains incomplete and is not release acceptance.

## Confirmed Heading Defect

Turret vehicles inherited the same world-forward heading regardless of
their position on the spawn ring. One seat faced inward, one outward,
and two sideways. `on_round_start()` now faces each valid fighter toward
the arena centre using the existing `face_direction()` helper, which
also synchronizes drive steering. Cooldowns, damage, speed, scoring,
projectiles, character stats, and the arena recipe are unchanged.
The actual match lifecycle calls this before AI round-start decisions.

The new two-round/four-seat fixture checks facing and drive yaw after
reset. RED: 62 passes, 12 failures, exit 1. GREEN: 74 passes, exit 0.
Existing projectile cleanup and protected-hit cases remain in that suite.
Turret network-state suite: 70 passes. All 442 scripts compiled.
Green logs individually passed the strict Godot log checker.

## Natural Before/After Comparison

Same local Godot 4.7.1 platform, seed offset 6800000, 64 baseline matches,
16 paired difficulty matches, two stress matches per run: 82 matches
before and 82 after. Independent comparison verified identical baseline
seed and character-roster arrays. No clipped rounds or forced scores.

Before fingerprint:
`c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`.
After fingerprint:
`63751e709a6ee8d4239a8c2ca0d5bf8a1aa7f999019f33477888aa77a8b5d644`.
Both reports' start/end fingerprints agree; the after fingerprint was
independently recomputed from the checkout.

| Measure | Before | After |
|---|---|---|
| Slot wins, including shared winners | [10,16,28,17] | [18,16,23,13] |
| Flags | spawn slot advantage | none |
| Expert edge | 0.6443 | 0.6617 |
| Tie rate | 0.078125 | 0.078125 |
| Average duration, seconds | 102.052 | 103.459 |
| Mutator and chaos smoke | both pass | both pass |

This supports retaining the inward-heading fix. One matched cohort does
not establish complete spawn/character fairness or all-arena balance.
Current-source follow-up is recorded below. Existing CI runs retain
b61e4b4 and do not certify the changed shipping code. No main merge,
deploy, archive or submission.

## Current-Source Regression and Real Peers

Tested commit: `4f78ae6ab044d33d46626f5239b3497eb839eac3`.
The full local headless suite passed 405925 assertions in 222.9 seconds,
exit 0. Its log also passed `tools/check_godot_log.sh` in `tests` mode.
This is a test-suite result, not an iPhone performance qualification.

`node network-smoke.js --game=turret_duel --humans=4 --seed=9614`
passed, exit 0, using four real Godot processes and a loopback WebSocket
service. One round ran on iron_flats, with a test-only 25-second duration
override. All peers agreed on scores `[5,9,3,7]`; the host and one guest
reconnected while retaining their peer IDs. Guests received 1488, 1508,
and 1508 world snapshots. The fixture requires observed projectiles,
damage and scoring, verifies guest replica agreement and rejects guest
projectile simulation. All four stdout logs passed the strict checker.
This is not a full-length round, tournament, WAN or Railway test.

The server event-loop monitor observed a maximum delay of 532 ms.
The separate sampled worst stall was 526.759 ms with 0.895 ms of
process CPU usage during its 626.759 ms wall-time interval. This makes
scheduling a candidate explanation, not a proven cause. Keep the
performance gate open; a functional PASS does not resolve this delay.

A sequential repeat with the same arguments plus `--scheduling-probe`
also passed, exit 0. All four peers agreed on `[3,5,7,9]`; host and guest
reconnects passed again. All four stdout logs passed the strict checker.
The event-loop monitor maximum was 197 ms; both the server's sampled
stall list and the independent idle probe's stall list were empty.
This did not reproduce the first run's stall, so its cause remains
unresolved. Different scores across runs also mean these real-time
network smokes are not evidence of deterministic input replay.
Repeat raw evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-k2U8mM/`;
preserved as `network-4f78ae6-9614-probe/`.

Raw full-suite log: `/tmp/kras-4f78ae6-full.stdout`.
Real-peer evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-9Olgn2/`.
Preserved alongside earlier evidence as `full-4f78ae6.stdout` and
`network-4f78ae6-9614/` under the directory below.

Raw evidence roots:
`/tmp/kras-turret-6800000-expanded-report/`,
`/tmp/kras-turret-heading-6800000-candidate-report/`, their stdout logs,
and `/tmp/kras-turret-heading-{red,green,network,compile}.stdout`.
Preserved copies: `../qualification-turret-heading-2026-10-09/`.
