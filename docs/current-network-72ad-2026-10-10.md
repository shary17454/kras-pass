# Current-Source Local Network Qualification

## Source

- Repository: `https://github.com/shary17454/kras-pass.git`.
- Branch: `feature/kras-online-random-rotation`.
- Tested commit: `21d1f7fc4e001566ca9bc8945dcbe0d76aa57031`.
- Godot: 4.7.1 official; imported runtime: `/tmp/kras-tank-pursuit-check`.
- Gameplay fingerprint: `72ad61069780e589372eb55c860c083d23cffc8b5f1d2910d0ec0801b50f45fa`.
- Server fingerprint: `072ca4c1630d5d72a049c007c7feb068082635f28c141bc2be5b79a9489e8d4f`.
  SHA256 of sorted filenames, NUL, and bytes for 67 server JavaScript/package
  files. Root and runtime matched before and after the campaigns.
- `network_peer.gd`, its scene, `network_smoke_config.gd`, and
  `tank_smoke_pilot.gd` also matched byte-for-byte. Individual hashes are in
  the saved source-validation JSON.

Gameplay fingerprint scope excludes assets, native archives, and test fixtures;
it is not a signed-build attestation. No gameplay or test source changed during
these campaigns. The initial server-copy comparison ran before its copy handle
completed and failed on package.json; comparison passed after completion, before
any qualifying network launch.

## Completed Cases

All commands used `GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js`
inside the isolated runtime's `server` directory. HTTP/WebSocket traffic was
loopback only. Two-client cases include two Bots; four-client cases have four
synthetic human-input providers, not four actual people.

| Arguments | Map | Groups | Rounds per group | Evidence suffix |
| --- | --- | --- | --- | --- |
| `--game=duel_pit --humans=4 --seed=80009001` | duel_pit | 4 clients | 1 | 9tC2eV |
| `--game=duel_pit --tournament --humans=4 --seed=80009001` | duel_pit | 4 clients | 3 | 31hyfd |
| `--game=turret_duel --seed=80009001` | iron_flats | 2 and 4 clients | 1 | dwT429 |
| `--game=base_siege --seed=80009001` | iron_flats | 2 and 4 clients | 1 | 06fTDH |
| `--game=boss_dreadnought --seed=9614` | iron_flats | 2 and 4 clients | 1 | wB5sLB |

Eight groups completed, comprising ten authoritative rounds and 26 peer results.
All groups reported PASS. Independent JSON checks verified unique peer IDs,
movement, matching scores, round histories, and tournament state. Every group
recorded restoration of IDs 1 and 2 after the fixture's injected disconnects.
The fixture checks preservation of the reconnecting player's prior ID and
restores the host after dropping its result message; it does not prove host
migration to a different authority or arbitrary production reconnection.

The three-round tournament completed with points `[11,6,8,10]`, cups
`[1,0,1,1]`, and champion slot 0 on all four peers. Its three score arrays were
`[3,2,13,2]`, `[6,3,0,12]`, and `[14,2,2,12]`.

`tools/check_godot_log.sh` accepted all 52 peer stdout/engine logs. Expected
transport-loss warnings remain in the raw logs because disconnects were
deliberately injected. The Siege and Dreadnought parents returned exit 0, as
did both Duel parents. The Turret observer handle was lost through output
truncation: the exact owned PID 42465 was observed running, then absent, with
both PASS groups and every peer finished. Its original exit code was not
recovered; an observer's exit 0 is not substituted for the parent's exit code.

## Performance Is Not Accepted

| Campaign | Largest recorded frame gap (ms) | Worst server interval delay (ms) |
| --- | --- | --- |
| Duel, four clients | 671 | 273.02 |
| Duel tournament | 989 | 292.58 |
| Turret | 1004 | 198.21 |
| Siege | 2673 | 268.85 |
| Dreadnought | 688 | no stall recorded |

The fixture's frame-gap maximum is cumulative from its `_process` calls,
including loading/transitions; it is not a steady-state FPS percentile.
These multi-process Mac results cannot establish iPhone 60/120 FPS, acceptable
thermal behavior, battery consumption, or a production server latency budget.
The functional PASS status does not remove these performance concerns.

## Evidence and Limits

Copied raw evidence, command stdout, timing JSON, and source validation:
`../qualification-current-network-72ad-2026-10-10/`.
Each raw group directory is named `kras-network-smoke-<suffix>` from the table.
The evidence is outside Git, locally retained, not a CI artifact or off-device
backup. Copies were compared byte-for-byte with the original logs.

Fixtures shorten authored durations and use synthetic inputs. This is not the
full natural-duration 39-game qualification, Sudden Death coverage, device QA,
or a real public/private-room production test. Duel's online allowlist exposes
only `duel_pit`; its local `iron_flats` variant was not tested online and was
not added to that allowlist during this checkpoint.

A transient File Provider timeout reading `.git/HEAD` occurred; subsequent
Git status and HEAD reads succeeded without recreating Git or deleting work.
No main promotion, remote push, Railway deploy/migration, new Archive, App
Store upload, or review submission occurred. Production backup/restore and
approval gates remain open. Stage 0 stays QA_PENDING/MERGE_PENDING; later
stages remain locked. Historical adbb/be795 balance results are not current
72ad acceptance, and no game becomes READY solely from this checkpoint.
