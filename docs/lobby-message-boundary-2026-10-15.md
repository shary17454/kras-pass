# Lobby message boundary - 2026-10-15

Status: client correction qualified locally, not production/device acceptance.
Starting commit: 9b16a38698fdfd739b748c60a78d129294e0d2fd.
Stage 0 remains QA_PENDING / MERGE_PENDING.

## Reproduced defect

Invalid room messages could replace the roster/configuration, clear input and
pending results, and request a UI refresh. Invalid welcome messages could replace
the peer identity/token and cancel the reconnect deadline. Invalid public room
occupancy reached the browser signal unchanged. The initial suite produced
1 passed / 26 failed, exit 1, without a fixture parse error.

## Correction

Net now validates `welcome`, `rooms` and `room` messages before their state changes
or presentation signals. Checks cover finite integral identities, bounded opaque
token strings, room code/state/capacity, unique peer IDs/slots, character indexes,
names and boolean ready/connected flags. Room lists are bounded to the server's
100-row maximum and reject duplicate codes or invalid occupancy.

Game/arena and round/difficulty validation is shared by lobby and start handlers.
Optional tournament settings validate the rotation, award table and unique known
playlist entries. Room tournament views validate their numeric arrays, bounds,
completion flag and unique finalist/champion slot indexes. Lobby slot holes after
leaving remain legal; a host may wait alone. Real peer IDs remain distinct from
the repeated zero IDs permitted for Bots in a start roster.

Rejected messages emit only the existing generic online error code, not their
payload/token, and do not partially overwrite the valid session. Accepted peer
and browser dictionaries are deep-copied, as config/standings already were.
No protocol version, authority rule, endpoint, backend, character stats, vehicle
physics, scoring or production setting was changed.

## Regression tests

New `tests/suites/test_network_lobby_boundary.gd` is registered in the standard
runner. It covers malformed shapes/fields, current online game/arena combinations
in all four room states, JSON numeric decoding, valid playlist/standings shapes,
slot holes, missing fields, invalid finalists, public list limits, and accepted
message copy isolation.

- Initial reproducer: 1 passed / 26 failed.
- Corrected reproducer: 27 assertions passed.
- Expanded new suite: 487 assertions passed.
- Existing start-boundary suite: 461 assertions passed.
- Existing network suite: 420 assertions passed.
- Compilation: 465 scripts, exit 0.
- Complete suite: 426486 assertions, exit 0, 241.7 seconds.
- Strict log guards passed for every positive run.

The complete suite's four ERROR lines are deliberate failed-write / screen-load
recovery injections, confirmed by test_save and test_router_recovery stack traces.
There were no script errors or failed assertions. Source remained frozen during
qualification; no campaign was restarted on an observer timeout.

Runtime source fingerprint before and after qualification:
`821bc2508158783a4ec8f354620364278293ea365201964284278e60e01f3df3`.

## Real WebSocket compatibility

Ran the existing harness with four independent Godot processes and a local server:

```
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=ring_rumble --humans=4 --seed=510172 --tournament --mixed-playlist --rotation=random_no_repeat
```

PASS, exit 0. The three match histories agreed on every peer:

1. goal_guard / quad_court: `[8,11,11,3]`
2. ring_rumble / storm_ring: `[8,8,8,8]`
3. hurdle_dash / hurdle_track: `[682,682,683,682]`

Final points `[9,11,8,8]`, cups `[2,3,2,2]`, champion slot index 1 (zero-based),
complete true. Host ID 1 and guest ID 2 reconnected. All eight engine/stdout logs
passed the stricter runtime guard. Server test suite, supplied with six actual
world captures from this complete Godot run, passed 276 tests with 0 failures and
0 skips. Dependencies/backend code were unchanged from the previous qualification.

This uses scripted input, loopback networking and existing shortened fixture
durations. It is not four real people/iPhones, natural-duration balance, every
online game, a public-browser UI walkthrough, or Railway connectivity. The sample
did not enter sudden death. Its approximately 32 ms server loop maximum is not a
phone FPS/energy or production-capacity measurement.

## Retained evidence

Sibling `../qualification-lobby-boundary-2026-10-15/` contains the initial/fixed/
expanded/start/network/compile/full engine logs, server TAP, eight real-process
logs and timing JSON in `network/`, and six synthetic world JSON captures only.
No private profiles, credentials or production database contents were copied.

SHA-256:

- Full-suite log: `46d8f3f4056a07faabc709c7e60d9584e9c6b77c3a6f5b5d5e5e155599327ea1`
- Server TAP: `963b8ff5735d8958c26155371e4b9b950c3103b0c64d0c912da7048be52fc5f2`
- Timing JSON: `49a1e56b59b7b507be391212c80f4a6d2fa4e0e24be0da990f3aa8b7545f1f5b`
- net_service.gd: `cfae91a834fda4e19e92d2ee29e6eb61d60fb893b2e4a14a5d2288ef71dc4f07`
- New suite: `e1a53a87ef60c72492f78923858eed68a3f9c8ff5f02ec259fd0132d055af5c4`
- Runner: `0f033c79bb0e5a06a323ca8d3859b03fcd1722e74ac300de9277c169e6c5ad29`

Other control-message envelopes, remaining game-specific/current-source E2E,
AI balance, real device/controller/orientation/energy QA and production backup/
restore/rollout remain separate open gates. No blanket security or release
approval is claimed. No main merge, push, Railway mutation, signed Xcode Archive,
App Store upload or review submission occurred.
