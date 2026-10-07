# Zone Observation History Qualification

## Source and Behaviour

- Branch: `fix/kras-zone-observation-history`.
- Runtime/test commit: `dc5109fee24d741f1f2063d631d91e80da13bdd3`.
- Base: `f6a0bd1b12fbd9fac9bd2233ed1689cd774c5ebc`.
- No main merge, Railway deployment, Apple Archive, upload or review.

Zone AI previously read live `zone_position` and `zone_radius` without
checking the rendered marker or applying reaction delay. The regression
reproduces steering toward hidden/new/moving zones with all four tier profiles.

The controller now returns position and radius from the rendered marker only
after the brain's shared visibility/geometry/camera/occlusion predicate passes.
Marker instance identity prevents a replacement borrowing another cue's history.
The brain retains at most HISTORY_CAP (32) decision-time observations and uses
the newest one at or before its configured reaction deadline. Repeated decisions
at the same simulation time do not append samples. This follows the existing
boss-cue decision-history pattern; it is not per-frame video or a new network
payload. Hidden cues and round restart clear history. Before a zone becomes
actionable, movement stops but existing edge safety remains enabled.

Capture/scoring, actual zone motion/speed/radius, rival perception, annular
route safety, dash limits, characters, saves and world snapshots are unchanged.
The observation deliberately uses rendered scale instead of an unrendered
logical capture radius. Hidden-zone memory is cleared rather than refreshed
from live state; camera-edge gameplay still needs device acceptance.

## Tests

- Original implementation: five passing / 32 failing assertions, exit 1.
- Initial correction: 37 assertions passed, exit 0.
- Expanded regression: 57 assertions passed, exit 0.
- Covers hidden and first observations, reaction boundary, delayed subsequent
  movement, hidden movement, reacquisition, round restart, rendered radius,
  marker replacement and bounded history, all four AI tiers.
- Compile: all 401 scripts passed.
- Zone routing, dash, scoring and replica lifecycle: 4,673 assertions passed.
- Shared AI visibility: 3,997 assertions passed.
- Scrub warning perception: 49 assertions passed.
- Painter/colour tile visibility: 41 assertions passed.
- Strict log guards and `git diff --check` passed.

Logs: `/tmp/kras-zone-perception-{red,green,expanded}.log`,
`/tmp/kras-zone-compile.log`, and
`/tmp/kras-zone-{zone_hold,ai_visibility,scrub_warning_perception,ai_tile_targets}.log`.
The earlier complete parent gate is not a new full test gate on dc5109f.

## Natural Matches

Current-source run at offset 600000 completed with exit 0: 24 natural baseline,
16 completed matched-seed/character difficulty and two passing mutator smoke
matches. Uses normal victory/timer rules, not forced early completion. Strict
log check passed. Log: `/tmp/kras-zone-natural.log`.

Runtime source remained unchanged during the run; start/end fingerprint:
`5a2fa278812e32663a2ed8956c65f8c89b7e76c00d47fe3bed5c4f2b9269a6b8`.
Expert edge 0.670659, slot bias 0.110000, character bias 0.115000, mean duration
97.520833 seconds, no report flags. Report:
`zone-observation-natural-600000.json`. This single sample has no paired
pre-change run and is not proof of balance improvement or all-arena readiness.

## Network Smoke

Four actual local peers with scripted human inputs completed with exit 0;
host/guest reconnect passed and all peers agreed on `[26, 0, 0, 0]`.
Guest world snapshot counts: 1,088, 1,107 and 1,107. Log:
`/tmp/kras-zone-four-peer.log`. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-3F8bsN`.
The 15-second smoke fixture is not physical four-player QA, natural AI balance
evidence, full tournament acceptance or production Internet acceptance.

Server event-loop summary maximum was 364 ms. The separate timing artifact's
worst stall recorded 307.191 ms delay / 407.191 ms elapsed, CPU 1.359 ms, during
playing. Input maximum wall time was 135.286 ms (CPU 0.165 ms at that sample);
snapshot maximum wall time 33.606 ms (CPU 0.901 ms). Natural simulation ran
concurrently. This is a latency qualification concern, not smoothness proof;
the cause is not established from low CPU time alone. Both summary and detailed
metrics are retained rather than silently selecting the better number.

After confirming the natural simulation was terminal, the same peer fixture
and seed were run again without that simulation. Exit 0, the same scores,
host/guest reconnect and guest snapshot counts passed. Repeat evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-7WgumD`;
log `/tmp/kras-zone-four-peer-isolated.log`.

Repeat summary maximum: 215 ms. Its detailed worst stall was 196.814 ms delay /
296.814 ms elapsed, CPU 2.057 ms during playing. Input maximum wall time
1.804 ms (CPU 0.074 ms), snapshot maximum 9.192 ms (CPU 0.286 ms). No other
applications were stopped, so this is not an otherwise idle machine benchmark.
Removing the natural simulation did not remove all stalls. The lower repeat
does not prove the first delay's cause or qualify production latency.

## Remaining Release Gates

AI fairness review remains incomplete, including siege/base cues and their
history. Per-game balance and device gameplay remain separate from passing
targeted assertions; no all-39 READY promotion is made here. Current-source
complete gates, physical iPhone/iPad/controller/orientation/battery/thermal
acceptance and production rollout/backup/auth/reconnect qualification remain.
Existing main-integration, protected backup and device-install confirmations
remain unanswered. App Store Connect access was not reasserted from old
login intent. Final approved source must receive current version/build numbers
and an exact-source local Xcode 27 Distribution Archive, then separate upload,
processing and review checks. No P12 import or certificate change occurred.
