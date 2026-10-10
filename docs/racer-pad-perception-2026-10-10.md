# Fair racing boost-pad perception

Base commit: `15279bfa95aaadeeb081a35c88d477bc81cf8e74`, branch
`feature/kras-online-random-rotation`. Candidate runtime fingerprint:
`e4c56526502dda4d61619177508c937cfc0c77369f02c4df9d07114348880ed2`.

## Defect and migration

Racer Brain previously selected detours from all controller boost-pad positions,
without checking visible geometry or first-observation reaction delay. This
could divert a bot to a hidden pad and retain immediate knowledge on reappearance
or recharge. Armed Racer inherits this racing decision.

Kart Sprint now retains each authored pad's mesh node and exposes pad nodes plus
the local player's recharge availability. Racer Brain tests visibility before
querying availability and uses the shared delayed-object perception. Hidden or
recharging nodes discard their observation history; reacquisition and round
restart require fresh reaction credit. History capacity/reset behavior remains
owned by AIBrain. No fallback to unrestricted positions is used by the bot.

The existing boost_pad_positions API is preserved for non-AI callers and tests.
Pad collision, recharge, visual construction and speed effect are unchanged.
The retained node is not included in serialized Kart Replica packets, whose
explicit position/cooldown fields remain unchanged. No new game or power-up,
character stat change or secret Bot speed advantage was introduced.

## Reproduction and regression

The new suite tests four difficulty profiles with a real rendered mesh and
shared perception: acquisition delay, hidden pad, reappearance, recharge and
round reset. Before correction: 17 assertions passed, 20 failed. After: all
37 passed. The fixture runs above the arena to isolate the visual cue from
unrelated terrain occlusion; this is not a real-device camera qualification.

Additional results:

- Race rounds/start grids/finish/reset: 1564 assertions passed.
- Kart network state: 121 assertions passed.
- Armed race network state: 176 assertions passed.
- Compile: all 450 scripts passed.
- Stability: one cycle, 39 matches, zero failures. Timed modes use shortened
  clocks; racing laps remain unchanged. This does not measure repeated-cycle
  memory growth, mobile performance, balance or four-human usability.
- All successful Godot logs passed the existing strict guard. Intentional
  cache-drain memory warnings remain preserved, not presented as zero warnings.

Raw failing/passing logs are retained at
`../qualification-racer-pad-perception-2026-10-10/`.

## Earlier CI and current gates

Core `38017220130` and Tank networking `38017226293` completed successfully on
d9c9c0a, before the Blast and racing perception corrections. Downloaded Tank
artifacts attest the clean exact checkout/run/scenario; all 22 peer stdout logs
pass strict guards. This is development-room evidence, not Internet production
or current-candidate network approval.

Core `38018319419` is in progress and all-game balance `38018326003` queued on
15279bf at this review. They exclude this racing correction. Preserve their
source and results; do not cancel/restart them solely to update the source.

Natural armed-race character balance, all-arena current-source qualification,
full remaining product features, device/controller/thermal checks, production
authorization and local-Xcode release preparation remain open. No stage DONE,
game READY, main promotion, Railway deployment, Apple upload or review submission
is claimed by this batch.
