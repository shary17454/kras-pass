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
not online-enabled. The room service now supports points/cups tournaments for
these two arenas, with stable rosters, readiness between matches, seeded
no-repeat rotation, and server-owned cumulative accounting. Only the host can
advance the tournament. The configured points table is validated server-side.

Final ties run short contender-only matches. Other players retain their slots
as spectators. At most three tie-breaks are allowed; persistent ties produce
shared champions, not an arbitrary slot-based winner. Cup tournaments also
have a bounded regular-round limit. These are push-arena tournaments, not
39-game online tournaments.

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
node network-smoke.js --tournament
cd ..
sh tools/check_party.sh
```

`network-smoke.js` starts an ephemeral loopback service and real isolated Godot
processes: two humans plus two bots, then four humans. Each runs two shortened
rounds, disconnects/reconnects one client, checks host receipt of remote input,
snapshot reception and identical results. It prints its evidence directory.
The tournament option also exercises repeated scene cleanup/loading, arena
rotation, next-round readiness and identical final standings on all peers.
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

The follow-up below completes full local regression and adds multi-engine
checks. The release gate still requires staging deployment and physical-device
and Internet QA. General 39-game
online support and networked tournament rotation are still future work.

## Release preparation follow-up (2026-10-02 session)

Work is isolated on `feature/kras-online-release`, based on main commit
`9135a741c474371c347db7a1c6759efc2f39d28e`. Untracked duplicate files ending in
` 2` in the original checkout were not deleted or included.

Implemented and regression-tested:

- Reuse vacant lobby slots without assigning two participants the same slot.
- Clear old results on lobby return; do not replay them on lobby reconnect.
- Give a disconnected host the full reconnect grace independently of its last
  snapshot's age, while retaining the connected-host authority watchdog.
- Apply a result once per match epoch; clear remote input at match boundaries.
- Retain a pending host result in memory until acknowledged, and retry only
  after the server confirms that the same epoch is still playing.
- Track generated Godot script UIDs. Ignore release screenshots/source artwork
  and generated iOS resources during Godot import without removing those files.

Verification:

- Node: 14 passing tests. The three new server regressions failed before the
  repair and passed afterwards. Dependency audit: zero reported vulnerabilities.
- Full `tools/check_party.sh` passed on the slot/reconnect/idempotency changes:
  222 scripts compile, inventory has zero issues, 12,423 assertions pass,
  independent race regression passes, 39 lifecycle matches have zero failures.
  Evidence: `kras-party-check.55Plas` under the host temporary directory.
- Real two- and four-human Godot sessions passed with movement, equal results
  and guest reconnect: `kras-network-smoke-NCgcT9`.
- The subsequent pending-result delivery change passed the focused network
  suite (27 assertions) and another 222-script compile check. Logs:
  `/tmp/kras-reconnect-tests.log`, `/tmp/kras-resume-final-compile.log`.
- A second real-engine run deliberately dropped the host's first result packet
  by closing its transport. Both two- and four-human sessions completed with
  identical results, host reconnect and guest reconnect. Evidence:
  `kras-network-smoke-f35E6w`. This verifies the pending-result delivery path.
- The native bridge build script now honors DEVELOPER_DIR and rejects a tools
  directory without the full Xcode toolchain. Shell syntax was checked; this
  is preparation only, not an archive or a native bridge build result.
- Sandboxed Godot emitted a macOS CA lookup warning; initial editor import also
  could not save global editor preferences. These are not successful device
  signing or network-authentication tests.

Live read-only release checks:

- Apple app 6801506973 is `com.shary.kraspass`; version 1.1.10 is READY_FOR_SALE.
  Build 107 is the most recently uploaded entry returned, while build 108 also
  already exists. Do not reuse either number or infer archive source from them.
- Existing distribution identity for team 4HM66AD594 is accessible in Keychain.
  Xcode 27.0 (27A266a) and a connected physical iPhone were detected. No P12 was
  imported and no certificate was changed.
- Railway source is shary17454/kras-pass, production/main, but its observed
  successful deployment is still c61005fd33e3821323379b56d9cfedd4a7407ce0.
  Required Apple variables are present, client/team match, SQLite uses /data,
  health is OK, and unauthenticated /account returns 401. Multiplayer is off.
  The last-24-hours error-log query returned no error entries. These checks do
  not prove a signed-device login, database migration, or a new deployment.

No new Apple archive/upload/submission or Railway deploy is established by
this follow-up. The 38 remaining online adapters,
Internet/device QA and the production feature-enable gate remain outstanding.

## Tournament follow-up verification

- Server tests: 21 passed, including cup targets, shared ties, contender-only
  scoring, reconnect standings, invalid configuration and duplicate results.
- Focused Godot network tests: 36 assertions passed. Contender IDs are tested
  through JSON decoding, not only integer-valued local fixtures.
- Actual Godot tournaments passed with two humans plus two bots and with four
  humans: six matches each (three regular plus three tied finals), matching
  standings on every peer, movement every active round, and both host-result
  loss and guest reconnect. Evidence: `kras-network-smoke-GycbbH` under the
  macOS temporary directory. Initial failed runs exposed late input/snapshot
  publication and JSON numeric-type contender matching; those were fixed.
- The successful tournament run still logged duplicate `leave/not_joined`
  during simultaneous cleanup. Leave is now idempotent; server regression
  tests cover that final adjustment. This did not change tournament scoring.
- Renderer QA captured lobby and final standings in portrait and landscape.
  It caught a nested-scroll collapse hiding the portrait round table. The
  inner scroll is removed, and the fixture now checks four visible-sized rows.
  Log: `/tmp/kras-tournament-ui-final.log`; screenshots:
  `/tmp/kras-online-results-1080x1920.png` and
  `/tmp/kras-online-results-1920x1080.png` (plus lobby equivalents).
- These tests use loopback on macOS, not Internet matchmaking or an iPhone.
  No claim of 39 online-ready games, phone performance, or release readiness
  follows from them. No production enablement or Apple submission was made.
- Full regression attempt `kras-party-check.0CNKEb`: compile (222 scripts)
  and inventory passed, but the integration suite became abnormally slow and
  was stopped after more than 25 minutes without recent log progress. It is
  **incomplete, not passed**. No assertion failure had been reported before
  termination; that does not establish correctness. The process sample is
  `/tmp/kras-party-stall.sample` (about 886 MB footprint, stripped native
  symbols, insufficient to identify a root cause). TestHarness now prints
  each test start to make the next isolated reproduction attributable.
- The separate stability run completed all 39 default-arena matches with zero
  failures after that interrupted full-suite attempt. Evidence:
  `/tmp/kras-tournament-stability.log` and
  `/tmp/kras-tournament-stability-save/stability.json`. This is one cycle with
  four AI and shortened timed rounds, not comprehensive multiplayer/device QA
  or a long-duration memory-leak certification.
- Final ordinary-match compatibility retests did **not** pass:
  `kras-network-smoke-bWHju8` closed on authority timeout, and
  `kras-network-smoke-p4gbw1` expired the session during transport recovery.
  Neither run reached a completed result. They coincided with unusually slow
  local command execution, but the cause is not established. Do not dismiss
  them as environmental or widen watchdogs to turn the test green. Reproduce
  with host tick/transport timing on a responsive machine before merging or
  releasing. Earlier successful tournament results do not override this gate.

## Expansion checklist per game

1. Define a bounded world-state adapter for all gameplay-visible dynamic objects
   (balls, projectiles, crates, hazards, ownership, effects), not just players.
2. Keep the host as the sole rules/score authority. Never simulate a second
   independent match on guests and call that synchronization.
3. Add malformed snapshot, reconnect, round reset and result tests.
4. Run real multiple-engine tests and device visual/audio QA.
5. Add the game to both server and client allowlists only after those pass.
6. Verify score direction and tournament placement for the new game, including
   contender-only tie-breaks, reconnect and host loss.

WebSocket is used here because the existing HTTP deployment can relay it;
its TCP latency tradeoff still requires real-network testing. References:
[Godot WebSocket guide](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html),
[ws](https://github.com/websockets/ws).

## Structure

```text
server/
  rooms.js             # protocol/state/ownership, independent of transport
  tournament.js        # points/cups, seeded rotation, bounded tie-breaks
  tournament.test.js   # accounting, ties, rotation and immutable views
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
