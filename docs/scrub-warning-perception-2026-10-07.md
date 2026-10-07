# Scrub Warning Perception

## Source

- Branch: `fix/kras-scrub-warning-perception`.
- Runtime/test commit: `c9be24808810da91aa5d7c2ff415d9bb75cc51b0`.
- Base/evidence commit: `fed8c36e90e690ba848468bd6e8da13e4d2bd2b8`.
- No main merge, production deployment, Apple Archive, upload or review.

The saboteur painter previously called `scrub_target` and reacted to the
controller's logical target immediately. The target could be read with every
rendered warning hidden or removed. This is a confirmed visibility and
reaction-delay issue, separate from the painter tile-selection fix.

## Behaviour

The controller retains a reference to its actual central white warning mesh.
The new `scrub_warning` query returns an empty observation unless that mesh
passes the brain's normal hierarchy/geometry/camera/occlusion checks. Its
position is obtained from the rendered marker, not from the live target tile.
`scrub_target` remains unchanged for authoritative presentation and tooling.

The brain starts its configured tier reaction delay at first observation.
Hidden/missing cues clear the observation. Reacquisition, a new warning serial
at the same location, a changed position and round restart require a fresh
delay. Existing avoidance range, edge-awareness chance, dash, painting,
character statistics, world snapshots and round rules are unchanged.

This deliberately requires an observed central marker before inferring the
patch centre. Merely seeing an outer white tile is not used to reveal an
off-screen centre. Human/device gameplay acceptance must evaluate the resulting
behaviour near camera edges. Bots do not receive a hidden-location fallback.

## Tests

Actual `mukharrib` scenes and white marker meshes, all four AI tiers; only
the avoidance command is intercepted by a probe. Reaction time comes from
each real difficulty profile. `edge_awareness` is set to one solely to remove
random failure from this regression, not in production.

- Before fix: five assertions passed, 44 failed, exit 1.
- After fix: 49 assertions passed, exit 0.
- Hidden cue, first observation, just before/at deadline, hide/reacquire,
  same-position new warning, restart and cleared marker covered.
- Compile: all 400 scripts passed.
- Saboteur network snapshots: 236 assertions passed.
- Shared AI visibility: 3,997 assertions passed.
- Compound visual cues: 26 assertions passed.
- Camera/world occlusion: 21 assertions passed.
- Painter/colour tile visibility: 41 assertions passed.
- Paint reset/claim lifecycle: 69 assertions passed.
- Strict log guards and `git diff --check` passed.

Logs are `/tmp/kras-scrub-warning-{red,green}.log`,
`/tmp/kras-scrub-compile.log`, `/tmp/kras-scrub-network.log`, and
`/tmp/kras-scrub-{ai_visibility,ai_compound_visibility,ai_occlusion,ai_tile_targets,paint_reset}.log`.
The parent full gate passed 372,802 assertions and 39 stability matches;
that parent result is not a new full gate on c9be248.

## Natural Gameplay Qualification

Current-source run at offset 600000 completed with exit 0 in 427.4 seconds:
24 baseline matches, 16 completed matched-seed/character difficulty matches
and two passing mutator smoke matches, using normal victory/timer rules
rather than forced early completion. Strict log check passed.

Start/end source fingerprint matches:
`39fc49ed138d218433d026c74930c4f159722762e34123c2175d063d64a70973`.
Expert edge 0.675000, slot bias 0.208333, character bias 0.083333, mean duration
96.267361 seconds; no report flags. Report: `scrub-warning-natural-600000.json`.
Log: `/tmp/kras-scrub-natural.log`. Runtime source remained unchanged during
the simulation; only evidence documents/reports were added.

There is no paired pre-change natural run in this qualification, so these
numbers are not evidence of balance improvement. The 20.8-point spawn spread
still warrants further independent samples and gameplay review even though
the small-sample report policy raises no flag. One 42-match sample does not
establish release readiness or fairness across all arenas and difficulties.

## Local Four-Peer Network

`node server/network-smoke.js --game=mukharrib --humans=4 --seed=609001`
completed with exit 0. Four actual local Godot peers agreed on scores
`[15, 18, 12, 17]`; host and guest reconnect passed. Guest world snapshot
counts were 1,107, 1,107 and 1,088. These are scripted human input providers,
not four human playtesters or a physical-device/production-Internet test.
The smoke fixture shortens this game to 15 seconds; it is not natural balance
evidence or a complete production tournament acceptance run.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-jcSR37`.
Driver log: `/tmp/kras-scrub-four-peer.log`.

Reported server-loop maximum: 336 ms. The retained timing artifact's worst
stall had delay 227.537 ms, elapsed 327.537 ms, CPU 0.101 ms, and no rooms.
Input handler maximum wall time was 0.471 ms (CPU 0.054 ms at that sample),
snapshot maximum 1.120 ms (CPU 0.157 ms). The natural simulation ran concurrently.
These observations do not establish the cause of the event-loop delay, and
do not qualify smoothness, mobile thermal behaviour or production latency.

## Broader Gates

The wider AI audit remains incomplete, including zone/base perception and
their reaction histories. Current natural balance and physical iPhone/iPad
performance, controller, orientation, battery and heat acceptance remain open.
Nothing in this focused test changes all 39 games to READY.

CI campaign `37549144464` was polled, not restarted or cancelled: seven game
jobs completed successfully, two game jobs live, 30 queued at this snapshot.
Its source remains 3c4bbdb6, not this commit. Job success alone does not prove
a balanced report or current-source qualification.

The newly completed magnet_court artifact was downloaded and checked against
source commit 3c4bbdb6d7437803cd53bba3e721b872ebb4675f, run 37549144464:
24 natural baseline / 16 completed difficulty / two passing mutator matches,
offset 900000. Start/end fingerprint
`cc80fc3c03e82587d7454edc8a401cfbda70d9133c4c7f9f3f10462efb06beaf`.
Expert edge 0.533654, slot/character bias both 0.083333, mean duration
36.017361 seconds, no report flags. Report:
`hud-campaign-magnet_court-natural-900000.json`. This is older-source evidence,
not a balance comparison for the scrub warning change.

Railway backup/rollout approval and fresh App Store Connect access remain
external gates. Existing device-install confirmation remains unanswered.
The final approved source needs current-number local Xcode 27 Archive and
Distribution signing before upload, processing and review can be claimed.
No certificate import, creation or revocation occurred.
