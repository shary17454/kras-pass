# Pickups obey local simulation pause

## Reproduction

Base commit: `7731ab3`, feature/kras-online-random-rotation.
Fighter movement and projectile travel are driven by the match simulation tick,
but ambient PowerUpPickup applied collection directly from Area3D.body_entered.
The physics server continues delivering overlaps while the match's local pause
flag stops its tick. A newly overlapping pickup could therefore change effects
and emit events while paused.

The regression creates a real ring_rumble match, spawns a speed pickup at the
fighter, pauses before the next physics frame, then awaits four real physics
frames. It does not call the collision handler or inject collection/effects.
Before the fix: 47 assertions passed, three failed. While paused, the speed
modifier became 1.45, a collection event fired and the pickup was retired.

## Repair

- PowerUpPickup no longer applies collection from the asynchronous body signal.
  Its collect_overlaps method validates active/monitoring state and a living
  Fighter and emits at most once.
- PowerUpSystem consumes overlaps during its simulation tick. Pickups are
  visited backwards because synchronous collection retires array entries.
- Scripted pickups still collect when ambient spawning is disabled: collection
  precedes that spawning guard. Existing bob/spin, spawner and pool APIs remain.
- No global SceneTree pause or change to online pause authority was introduced.

The expanded test uses two simultaneous pickups (speed and shield), with
ambient spawning both enabled and disabled. Neither pickup is consumed during
pause; explicit resume grants each ordinary effect and retires both, with only
one speed collection event. This also guards against skipping an entry when a
different pickup is retired. Expanded lifecycle suite: 58 assertions, exit 0;
strict test log guard passed. Initial single-pickup green run: 50 assertions.

## Qualification

Godot 4.7.1.stable.official.a13da4feb, isolated writable HOME and test saves.
All 466 scripts compiled; strict compile guard passed. Complete suite with the
documented --headless --fixed-fps 60 invocation passed 427981 assertions in
386.6 seconds, exit 0. Strict tests log guard passed. Four ERROR entries were
individually checked: intentional failed-save and three router-recovery cases.
No source/test changes overlapped qualification.

The full suite exercises replay and match completion, but does not prove old
and new gameplay are identical. Consumption now occurs at the simulation tick,
not the asynchronous overlap callback; ordering/timing can change natural
results. For example, the ring_rumble integration log now completes at 18.9s
rather than the previous 21.0s. Existing balance reports are not promoted as
qualification of this source. No physical-device, sustained-FPS, energy or
thermal claim, and no new multi-process network campaign is claimed.

Runtime selected-source fingerprint remained:
`822cb23e2dafd2e0329ba9da190458f01ced0a0c9d527246710571804f458ee7`.
This fingerprint excludes tests and many assets and is not archive attestation.
Changed-file SHA-256 values, separately matched to the checkout:

- src/powerups/powerup_pickup.gd: `96f9b4a987ac1f7b3d0ab022298b5b787184aca222d5f4bcc519b665a6f784b9`
- src/powerups/powerup_system.gd: `91cb5455e4a4de2ed2c5961ecea7bb9378fc0995ce71555f229fcd5cc8048fae`
- tests/suites/test_lifecycle.gd: `bd26974516fca0dcb706c94472e613830dfa25b1baa44f93eb64a3e02dd58c8f`

Full log SHA-256:
`bbcc4f1c9139474146bf39c41e78e3d8b115a89fd056197b688f330d01b2bf52`.
Sibling qualification-pause-pickup-2026-10-15/ preserves red, initial green,
expanded green, compile and completed full logs. Private saves were not copied.

Stage 0 remains QA_PENDING/MERGE_PENDING. Balance, broader visual/device QA and
production backup/restore authorization remain open. No main push, deployment,
new archive, upload or Apple review submission occurred.
