# Collection network qualification - 2026-10-15

Status: selected local functional evidence; Stage 0 QA_PENDING / MERGE_PENDING.
Checkout at execution: f37b427de68a11e6ce5d70e6f151b0cebb967a5c.
Branch: feature/kras-online-random-rotation.
Gameplay fingerprint before and after both campaigns:
`42a6fc20cd43415a36eb13d70d645b783b0afce52b4198c03d1f2c1a7bc65476`.
No source or test changes overlapped execution.

## Commands and outcomes

Using Godot 4.7.1, the existing isolated runtime and HOME, with a real loopback
WebSocket service and four independent Godot processes per campaign:

```sh
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=gem_grab --humans=4 --seed=510175
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=star_rush --humans=4 --seed=510176
```

Both commands exited 0 with PASS. All peers observed movement and collection
scoring. Host ID 1 and guest ID 2 reconnected in each campaign. All sixteen
engine/stdout logs passed `tools/check_godot_log.sh` in strict runtime mode.

| Game / arena | Agreed scores | Guest world snapshots | Carrying observed |
| --- | --- | --- | --- |
| gem_grab / gem_hollow | [8,10,4,4] | 912-931 | false; not required here |
| star_rush / star_meadow | [5,4,8,10] | 1088-1107 | true on all four peers |

The existing peer test validates guest item presentation positions/counts and
local carrying state against authoritative world snapshots. Final scoring was
observed, not just receipt of a result message. Scripted inputs and shortened
fixture durations are used; these are not human playability or balance tests.

## Performance limits

The server reported maximum event-loop observations of 23ms and 24ms.
Host cumulative maximum frame gaps were 387ms and 349ms respectively. These
measurements do not isolate steady gameplay from loading/transition costs and
do not qualify 60/120 FPS, rendering quality, physical-device memory, energy,
thermal behavior or production network latency.

## Evidence

Preserved outside Git under the workspace:
`qualification-collection-network-2026-10-15/{gem_grab,star_rush}/`.
Each subdirectory contains four engine logs, four stdout logs and server timing.
Private test save directories were not copied.

Original harness output directories:
- gem_grab: `kras-network-smoke-VAhVyi`
- star_rush: `kras-network-smoke-0AtBj6`

SHA-256 of preserved server-timing.json:
- gem_grab: `9715d8300d33469ce74780e409bf90918a430caddee2a8e156c54e8023028c68`
- star_rush: `dd01a491c1ea76ef13507738d8833158f86f9b479fd827d4484927f658a93675`

No gameplay edits, full-suite rerun, Git push, merge, production deployment,
iOS archive, upload or App Review submission occurred in this stage. These two
arenas are not qualification of all collection variants or all 39 minigames.
