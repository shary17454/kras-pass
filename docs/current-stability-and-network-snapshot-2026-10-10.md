# Current stability and source-qualified network snapshot

## Current local stability

Checkout `104acb9026bee33751a106f81af90d915409ad23`, branch
`feature/kras-online-random-rotation`, contains runtime source `5b07018`.
The isolated runtime fingerprint was unchanged before and after this campaign:
`c6997498a03697a4c59d66bb1cf99ef2016098bc982dcaf88ace346df6e1cf81`.

Command: Godot 4.7.1, `--headless --fixed-fps 60`,
`tests/stage_zero_stability.tscn -- --cycles=3`, isolated test-data directory
`/tmp/kras-current-c699-stability-save`.

- Completed 117 matches: three cycles of all 39 games, four AI per match.
- Exit zero, no reported match or cleanup failures; strict log guard passed.
- Each timed round is shortened to five seconds. Race laps are unchanged.
- The harness checks one completion callback, complete ranking and natural
  result state, finite positions/velocities, weak-reference release, baseline
  nodes/orphans/signals, cleared shared-pool ownership and detached input sources.
- Baseline: 51 nodes, zero orphan nodes.
- End-of-cycle static memory: 264335204, 266428472, 267366528 bytes.
- Post-warmup growth: 938056 bytes, below the existing 16 MiB failure limit.
- A simulated memory warning cleared all material, texture and mesh caches.
  Settled static memory: 145145320 bytes; 122222892 bytes were released.

The explicit simulated OS memory warning appears in the log and is retained.
The approximately 40.8 MB initial baseline was not restored: cached script,
resource and other engine allocations remain. This is not a zero-leak claim,
an RSS/GPU-memory measurement, or physical-device thermal/FPS acceptance.

Evidence:

- `/tmp/kras-current-c699-stability.stdout`
- `/tmp/kras-current-c699-stability-engine.log`
- `/tmp/kras-current-c699-stability-save/stability.json`

## Separate downloaded network evidence

Run `38022898755` remains a separate, captured-source campaign:
`c0a5b6c6d3b9cb0875c47aa9c87c5ada1ce39b9c`, tree
`6dabc1c34e2e4dfae06ef5c23b7584c99b5f9684`.
All eight downloaded artifact manifests match the intended checkout, run ID
and scenario, with no tracked changes. These artifacts precede the current
crate-pickup fix; they must not qualify that fix automatically.

The completed Core artifact contains 407827 assertions, 404.2 seconds, and
117 stability matches with no recorded failures. Test and stability outputs
passed the strict log guard. Actual-capture server tests: 276 passed, no failed
or skipped tests. A four-peer mixed playlist completed hurdle dash, goal guard
and ring rumble, agreeing on one champion and final standings.

Seven completed game artifacts were inspected: gem grab, goal guard, relic
hold, ring rumble, star rush, tag hunt and zone hold. Their two- and four-peer
single-match and tournament summaries passed. Ninety peer logs contain a
`NETWORK_FINISHED` result and passed strict log guards. Tournament peer scores,
round histories and final standings agree; host and tested client reconnects
are recorded. These are automated loopback peers, not Internet/device tests.

Six games' tournaments ended after three rounds with one champion. Ring rumble
ended after three regular rounds and three tied finals, with four shared
champions in both roster sizes. The existing bounded-shared-championship policy
is explicitly covered in `server/tournament.test.js`. A stronger audit requiring
one champion rejected these two outcomes; they are not evidence that every
tournament always resolves to a sole winner. No production behavior or test
assertion was weakened to make the audit green.

Downloaded snapshot:
`/tmp/kras-network-c0-38022898755-snapshot/`.
Remaining network jobs were still queued/running when polled; this is not a
completed all-39 network campaign. No job was cancelled or restarted.

## Gates remain open

Current-source full natural balance, all-39 network acceptance, real-device
gameplay/performance/energy, production backup/restore and migrations, final
local Xcode 27 archive, Apple upload, processing and review submission remain
separate unfinished gates. The main-push permission rejection was not bypassed.
No runtime was changed by this qualification report and no stage became DONE.
