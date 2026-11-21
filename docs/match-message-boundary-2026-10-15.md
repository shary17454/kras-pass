# Match messages and authoritative result boundary - 2026-10-15

Status: verified local correction. Stage 0 remains QA_PENDING / MERGE_PENDING.
Starting commit: 605eec0cea529513af6c3d3815e20d80b1bae322.

## Reproduced defect and correction

Malformed results could stop simulation, consume the result epoch, clear pending
delivery recovery and reach presentation. Fractional go epochs and snapshot ticks
were truncated into integers. Initial regression: 1 passed / 34 failed, exit 1,
with no fixture parse error.

Net now checks result shape, active roster length, finite integer values and
catalogue score direction before acknowledging it. The bounds match
server/game-scoring.js: normal maximum 1000000, kart/special-race sentinel maximum
1000000000 times configured rounds; race-time results are nonnegative, other
scoring types permit down to -1000000. Optional standings must be complete and
match the result roster; configured tournament results cannot omit standings.
Accepted score arrays are copied before presentation.

Match envelopes validate epoch/tick/stamp integers, snapshot dictionary shape,
input slot/sequence/button bounds and four finite axes, and bounded textual error/
closure metadata before conversion. Older/duplicate input sequences cannot
overwrite latest movement or requeue a released attack.

This does not replace deeper world/entity snapshot validators or the server's
authority checks. No packet version, backend, timing budget, character stats,
physics, score formula or tournament award table changed.

## Tests and fixture correction

New test_network_match_boundary.gd is registered in the standard runner. It
tests malformed results without partial state changes, all 39 catalogue result
contracts at one/ten rounds, JSON integer decoding, malformed match envelopes,
complete/missing/mismatched standings, valid acknowledgement after rejection,
score-array copy isolation and old input replay.

The existing network result fixtures lacked active match metadata and used a
partial standings dictionary, unlike the real server. Added a realistic two-player
match context and complete standings fields. Existing behavioral assertions were
retained unchanged; that suite still has 420 assertions. Validation was not
weakened to accept the old partial fixture.

- Initial reproducer: 1 passed / 34 failed; corrected: 35 passed.
- Expanded suite before final copy assertion: 1187 passed.
- Final focused suite: 1188 assertions passed.
- Existing network suite: 420 assertions passed.
- Compilation: 466 scripts, exit 0.
- Complete suite: 427673 assertions, exit 0, 224.9 seconds.
- Strict guards passed. Full-log ERROR lines are the four deliberate Save/Router
  failure injections, verified by their test stack traces, not runtime cleanliness.

Frozen source fingerprint before/after all qualification:
`42a6fc20cd43415a36eb13d70d645b783b0afce52b4198c03d1f2c1a7bc65476`.
No source edits overlapped qualifying processes.

## Real network tournaments

Executed the existing harness sequentially for two and four network peers:

```
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=ring_rumble --seed=510173 --tournament --mixed-playlist --rotation=random_no_repeat
```

Both scenarios passed, exit 0. All peer histories, scores and standings were
compared from retained stdout. All 12 engine/stdout logs passed the strict runtime
guard. Host ID 1 and guest ID 2 reconnected in both scenarios.

Two peers plus two Bots (four score slots):

- Three ordinary games: ring_rumble / vortex_ring, goal_guard / quad_court,
  hurdle_dash / hurdle_track.
- Ordinary points `[8,10,7,10]` tied slots 1 and 3; two additional sudden-death
  games on storm_ring then hurdle_track resolved the tie.
- Five matches total, tie_attempts 2, champion slot index 1 (zero-based).
- Ordinary points/cups were not increased by the final tie-break games; final
  awards were all zero. The host's last-match moved flag is false: movement is
  reset per fixture match and host slot 0 is outside this final's contenders.
  This is not an all-match movement/performance acceptance claim.

Four network peers:

- Three ordinary matches on vortex_ring, quad_court and hurdle_track.
- Final points `[10,9,6,9]`, champion slot index 0, no tie-break needed.

These are scripted processes on one Mac using loopback and existing shortened
fixture durations, not four people/iPhones or production networking. The scenarios
cover three game types/four selected arenas, not every game's online qualification.
Observed server loop maximum approximately 23 ms is not a phone FPS/energy metric.

Server regression, supplied six actual-world JSON captures from this complete
Godot run: 276 tests passed, 0 failures, 0 skipped, exit 0.

## Evidence and remaining gates

Sibling `../qualification-match-boundary-2026-10-15/` retains engine logs, final
server TAP, 12 peer logs plus timing JSON in network/, and six synthetic world
captures. Private profiles, credentials and production data were not copied.

SHA-256:

- Full log: `d40d38063f737f5b9d4f6562f24eba313c4c0e67f4cf583eb2b1cbb9bebfd766`
- Server TAP: `0c14d8b298870ad093998a832098ea27e99873bd713dc92f31cee6189931bc89`
- Timing JSON: `4f0e7b07915118b7adaa4d624f474f99d0d2d6dc63e6e62747b0cb55dd40494e`
- net_service.gd: `a55cb0605a8155a0821f60a2d750d1c5b8b424e304f74767e996858bf4e4bee0`
- New suite: `5837eb3960cd7aede866da1e7494b23fbcde2e24a50b99c483574b3cd5d182c7`
- Updated network fixture: `e0acdb166490b2b356156320a59dad3907ff3fc72136c689b5470ebb2140efb2`
- Runner: `4e12ed330ffbfd9dce5d9061b863d8ca45ab9fd1def52b0a4da04bfbc27cb4e9`

AI balance, remaining current-source game/variant coverage, physical-device input/
orientation/energy/performance, production backup/restore/rollout and real native
production connectivity remain open. No blanket security, READY or release claim.
No main merge, Git push, Railway mutation, signed Xcode Archive, upload or Apple
review submission occurred.
