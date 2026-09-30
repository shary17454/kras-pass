# Online beta: protocol 1

## Implemented boundary

The existing local match runtime remains authoritative on the host device.
The Node service authenticates **connection ownership**, not Apple accounts,
and controls room membership, readiness, loading barriers, slot assignment,
match epochs and access to snapshot/result publication. Guests cannot publish
another player's input or a result. The host is trusted: this is not a dedicated
anti-cheat simulation and is not suitable for ranked rewards.

Public discovery and six-character private codes use real WebSockets at
`/multiplayer`. Up to four people can join; empty places can be filled by host
AI. The lobby has character selection, readiness, host kick, arena, difficulty
and 1-10 rounds. Local input remains keyboard, gamepad or touch.

Online currently exposes **only the explicit push-arena beta ruleset**:
`ring_rumble`, `vortex_ring` / `storm_ring`, without machine drops, random
power-ups or bombs. Offline Ring Rumble is unchanged. This avoids presenting
unreplicated hazards/items as if they worked remotely. The other 38 games are
not online-enabled. Cup/points tournament rotation remains local, not online.

Clients render host snapshots at 20 Hz with smoothing; they send input at
30 Hz. The host simulates at the engine physics frequency. Remote clients do
not evaluate scores, winners, collisions or timers. Snapshots include fighter
pose/velocity/status, shrinking radius, phase, round, countdown and scores.
Results travel once through the server after host completion. Online results
do not grant local progression or create misleading input-only replays.

## Recovery and bounded resources

- A cryptographically random bearer resume token is sent only to its owner.
  It is kept in memory, never logged, included in room discovery, or saved.
- The reconnect grace is 30 seconds. Slot/character/score identity survives a
  transport reconnect in the same running app. Stale inputs become neutral
  after 250 ms; this beta does not silently replace disconnected people by AI.
- A still-active old connection returns `session_active`; the client retries
  while the server heartbeat detects the dead connection.
- No host migration. A host loss pauses authoritative updates; expiry closes
  the room without fabricating a winner. Guest expiry during a match also
  aborts this beta rather than changing roster/scoring under the players.
- Loading has a 60-second timeout. Missing host snapshots have a 30-second
  watchdog. Idle rooms expire after 30 minutes.
- Limits: 200 rooms, 800 connections, 16 connections per socket IP, 64 KiB
  packets, 48 KiB snapshots, 90 messages/s, 12 control messages/s, 256 KiB
  outbound backlog. No compression and no arbitrary Godot object decoding.
- Browser Origins are denied unless explicitly allowlisted. Native clients
  omit Origin. Production clients require WSS; WS is loopback-only.

## Local verification

```sh
cd server
npm ci --ignore-scripts
npm test
node network-smoke.js
cd ..
sh tools/check_party.sh
```

`network-smoke.js` starts an ephemeral loopback service and real isolated Godot
processes: two humans plus two bots, then four humans. Each runs two shortened
rounds, disconnects/reconnects one client, checks host receipt of remote input,
snapshot reception and identical results. It prints its evidence directory.
This is a networking smoke test, not proof of Internet latency, phone thermal
behavior, game balance or visual/audio parity.

## Railway deployment gate

The account service and SQLite storage are preserved. Multiplayer is **off by
default**. Do not enable production just because the loopback tests pass.

1. Deploy the reviewed feature commit to a separate Railway staging service
   using the existing Dockerfile. Preserve account variables and `/data` volume
   if sharing an account-service instance. Never copy secrets into Git.
2. Set `MULTIPLAYER_ENABLED=true`. For native clients no Origin list is needed;
   set `MULTIPLAYER_ORIGINS` only to exact trusted browser origins if web export
   is used. Configure one replica: rooms live in process memory, not SQLite.
3. Verify `/health` and WebSocket upgrade to `wss://<staging-domain>/multiplayer`.
4. Run the client with `KRAS_MULTIPLAYER_URL` for desktop QA, or set the Godot
   project setting `kras/online/endpoint` in a staging export. The default
   shipping project has no enabled endpoint.
5. Test four physical devices, Wi-Fi/cellular transitions, backgrounding,
   high latency, packet loss, portrait/landscape and long sessions.
6. Only then enable a production endpoint in a reviewed build. Shutdown/redeploy
   closes active rooms explicitly; it cannot resume a simulation after a server
   or host process restart. Rollback: disable the endpoint/feature flag; local
   gameplay and Apple authentication remain available.

No Railway deployment, App Store upload, or review submission is implied by
these changes. Use actual deployment evidence to update that status.

## Verification record (2026-09-30)

- Node account + room tests: 11 passing, including four real WebSocket clients,
  malformed/unauthorized packets, reconnect identity, load timeout and host
  snapshot watchdog. Dependency install audit reported no vulnerabilities.
- Godot network unit suite: 17 assertions passed (snapshot validation, slot
  ownership, stale-input expiry and session cleanup).
- Final compile check: all 222 GDScript files compiled successfully; evidence
  `/tmp/kras-network-final-compile.log`. This does not replace runtime tests.
- An initial real-engine run passed two-human/two-bot and four-human sessions,
  two rounds each, with identical results and a guest reconnect:
  `/tmp`/macOS temporary directory `kras-network-smoke-A72oxL`.
- Subsequent runs were not reliably repeatable: connection expiry and process
  timeouts occurred while multiple Godot engines were running. The client now
  logs close codes, and the server heartbeat respects the scene-loading budget.
  One later run (`kras-network-smoke-swdSvl`) timed out before the two-player
  room started. These load-sensitive failures are retained as QA evidence.
- The final isolated run on the current code (`kras-network-smoke-JRi1Of`)
  passed both two-human/two-bot and four-human sessions. Every human moved,
  results matched across devices, and peer 2 reconnected in both sessions.
  Guests received 648-668 snapshots. This is loopback verification, not a
  guarantee under network loss, device suspension or heavy resource pressure.
- The full local regression run `kras-party-check.JYuHn9` passed compilation
  and content inventory but was stopped after prolonged integration execution;
  it has **no final passing result**. Re-run on an unloaded test host.
- A subsequent standalone lifecycle run completed **39 matches, 0 failures**
  with four AI players, shortened timed rounds and normal race laps. It checks
  result validity, cleanup, retained objects, input and global signal ownership.
  Evidence: `/tmp/kras-network-final-stability.log` and
  `/tmp/kras-network-final-stability-save/stability.json`. One cycle does not
  establish long-session memory stability or physical-device performance.
- Arabic lobby fixture screenshots were inspected in landscape and portrait;
  these are presentation fixtures, not evidence of device/network performance.

Release gate remains closed pending sustained multi-engine tests, completed
full local regression, staging deployment and physical-device QA. General 39-game
online support and networked tournament rotation are still future work.

## Expansion checklist per game

1. Define a bounded world-state adapter for all gameplay-visible dynamic objects
   (balls, projectiles, crates, hazards, ownership, effects), not just players.
2. Keep the host as the sole rules/score authority. Never simulate a second
   independent match on guests and call that synchronization.
3. Add malformed snapshot, reconnect, round reset and result tests.
4. Run real multiple-engine tests and device visual/audio QA.
5. Add the game to both server and client allowlists only after those pass.
6. Add online tournament state on the room authority with idempotent per-round
   results and tests for ties, cups, playlists and host loss.

WebSocket is used here because the existing HTTP deployment can relay it;
its TCP latency tradeoff still requires real-network testing. References:
[Godot WebSocket guide](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html),
[ws](https://github.com/websockets/ws).

## Structure

```text
server/
  rooms.js             # protocol/state/ownership, independent of transport
  multiplayer.js       # bounded WebSocket transport, heartbeat, shutdown
  rooms.test.js        # state and actual four-socket integration tests
  network-smoke.js     # real multi-process Godot integration
src/net/
  net_service.gd       # local + online session coordinator
  room_client.gd       # Godot WebSocket transport
  match_replica.gd     # presentation-only push-arena adapter
tests/
  network_peer.gd      # actual match client used by the smoke test
  suites/test_network.gd
```
