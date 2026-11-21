# Tank three-contender network final - 2026-10-15

Status: selected local integration scenario passed, not full Tank acceptance.
Source: f34915abb1c426c9a526736db6a0acf7338b91ba.
Gameplay fingerprint before/after:
`42a6fc20cd43415a36eb13d70d645b783b0afce52b4198c03d1f2c1a7bc65476`.
The preceding privacy-tool edit does not change runtime gameplay.

## Actual execution

```
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=tank_arena --humans=4 --tournament --tank-three-final-checkpoint
```

Used the existing checkpoint fixture, four independent Godot processes and a real
loopback WebSocket server. The fixture restores tournament round 3 with points
`[10,7,10,10]`, cups `[2,1,2,2]` and contenders `[0,2,3]` before starting epoch 4
on tank_foundry. It does NOT play the ordinary tournament rounds from scratch.

Result: PASS, exit 0. All four distinct peers agreed on:

- Final round scores `[300,100,500,200]`.
- Completed tournament, champion slot index 2 (zero-based), tie_attempts 1.
- Ordinary points/cups unchanged from the checkpoint; final awards all zero.
- Host ID 1 and guest ID 2 reconnected; pending host-result recovery succeeded.

All eight engine/stdout logs passed the stricter runtime guard. The guest in
slot 1 was outside the restored contender set and has moved=false; the other
three slots moved. This is an excluded spectator, not four active contenders.
Guests received 386-405 presentation/world snapshots. The observed server loop
maximum around 22 ms is not phone FPS or production latency/capacity proof.

## Limits and evidence

This uses scripted inputs, one authored Foundry arena and an existing restored
final fixture. It is not natural-duration Tank balance, every shell/map/variant,
four physical players/devices, a complete ordinary tournament, or production
online gameplay. It does not resolve the outstanding Expert balance warning.
No source changes overlapped the run.

Sibling `../qualification-tank-network-final-2026-10-15/` retains eight process
logs and server-timing.json only, not private save profiles or credentials.
The previous complete 427673-assertion Godot run and 276 server tests were not
rerun or recounted in this stage. Runtime source remained unchanged.

Stage 0 remains QA_PENDING / MERGE_PENDING. Remaining current-source scenarios,
device/controller/orientation/energy testing and production/release gates remain
open. No main merge, push, Railway mutation, Archive, upload or Apple submission.
