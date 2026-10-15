# Real mixed-tournament network qualification

## Source and method

Base commit: c76ab56752210389b5fa44cfed721d388cc83277.
The only runtime-test additions were `--mixed-playlist` configuration and
per-round evidence in `tests/network_peer.gd` / `server/network-smoke.js`.
No game controller, scoring rule, input driver, server result or winner was
overridden for this scenario. The existing smoke-test duration overrides and
scripted human input drivers still apply; this is not normal-duration user QA.

Command:

```sh
node network-smoke.js --tournament --mixed-playlist --rotation=random_no_repeat --humans=4 --seed=17
```

Four separate official Godot 4.7.1 macOS processes used isolated profiles and
the real WebSocket service on loopback. Selected entries included two ring
maps, one ball map and one hurdle map, intentionally giving one game more maps.
The first cycle still visited three distinct games.

## Observed result

- Hurdles, `hurdle_track`: scores 692, 693, 693, 693 (lower wins).
- Ball, `quad_court`: scores 7, 9, 11, 10 (higher wins).
- Push, `vortex_ring`: scores 8, 8, 8, 8 (tied round).
- All four peers agreed on every round's epoch, game, arena and scores.
- All agreed on final points 9, 7, 10, 8; cups 2, 1, 2, 1; champion slot 2.
- Host result transport was deliberately dropped; the actual host resumed
  with its identity and its result reached the server.
- One guest transport was dropped during play; that guest resumed with its
  identity. Other guests remained connected.
- Each guest received at least five new snapshots in every mixed round.
- Host observed all three remote input slots in each round. Every participant
  moved; final snapshot totals for guests were 1444, 1425 and 1444.
- All four process logs passed the existing runtime error/leak guard. Wrapper
  exit was zero and final status PASS. Server loop maximum delay was 98 ms;
  this is not a mobile FPS or WAN-latency result.

## Additional checks

Local compile: all 424 scripts pass. The initial isolated attempt could not
write the user log and terminated with an engine signal; that attempt is
preserved separately and is not treated as passing compilation.

Six capture-producing Godot suites passed their strict test guards:
armed race 176, siege 129, forge 141, dreadnought 117, sovereign 141,
colossus 155 assertions (859 total). Their generated snapshots were supplied
to the full Node suite: 243 passed, zero failed, zero skipped.

The core Linux CI job now includes this mixed scenario and preserves its
normal network artifacts. The workflow change is not itself evidence of a
completed CI run.

## Remaining release gates

This closes only the three-game loopback mixed-tournament check, not the full
39-game product requirement. Current full Godot regression remains incomplete
after disk-space failures. Production Railway, real-device/controller QA,
balance and performance, latest-source main integration and local Xcode 27
archive/upload/review submission remain open. No production deployment or
Apple submission was performed here.

Evidence: `docs/qa/online-mixed-real-peers-2026-10-08/`.
