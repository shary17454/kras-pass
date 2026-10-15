# Crate Smash authored-duration tournament

Source: `babcf829532f7882fcbe2f8dc81fa01299ede065` on
`feature/kras-online-random-rotation`. The tracked working tree was clean
before launch and no code was changed during this run.

Command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot node
network-smoke.js --game=crate_smash --humans=4 --seed=3904242 --tournament`.
Four actual Godot processes used scripted inputs and a real ephemeral
loopback WebSocket service, with isolated test saves and no production
credentials. Crate Smash uses its authored duration, not the former 15-second
override. This is not four physical players or an Internet test.

## Functional result

The runner exited 0. All four peer logs passed the strict runtime guard.
Each peer reported three completed matches and identical round history:

| Match | Scores |
| --- | --- |
| 1 | 29, 12, 19, 22 |
| 2 | 29, 28, 15, 30 |
| 3 | 39, 36, 7, 10 |

Final points `[13,6,4,10]`, cups `[2,0,0,1]`, awards `[5,3,1,2]`, champion
slot 0, complete true, round/target 3. Host and guest 2 reconnected.
Guest world snapshot counts: 5265, 5287, 5287. No tie occurred; this run does
not prove Crate Smash sudden-death gameplay. The normal server ranking and
tournament accounting were used without score injection.

## Performance remains unqualified

Maximum server event-loop delay was 762 ms. The scheduling timer recorded
535.195 ms excess delay during match 3 (635.195 ms elapsed, 12.823 ms process
CPU). The slowest resume operation took 296.034 ms wall time and 1.182 ms
process CPU. Low measured CPU is not proof of the stall's cause or that
gameplay latency is acceptable. No independent scheduling probe was enabled
in this run. Preserve these failures of smoothness qualification; do not
relabel the functional PASS as performance acceptance.

Raw synthetic runner output and timing diagnostics are retained under
`qa/crate-authored-tournament-2026-10-08/`. Raw saves/session credentials are
not included. Original evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-mDkfGF`.

Current-source Core CI was dispatched as run `37768869605` after confirming
no earlier same-branch run was active. Its checkout is the exact source
above; the last verified state was in progress, not a passing result. It is
Linux Godot/server QA, not Xcode Cloud or an Apple archive.

Physical-device gameplay, sustained FPS/energy/thermal acceptance, current
all-game balance/visual qualification, production rollout and positive native
connection, exact-source signed local Xcode 27 archive, upload, processing
and separate App Review submission remain open. The Mac was still locked
when its available UI surfaces were checked during this run. No main merge,
Railway deployment or Apple operation occurred.
