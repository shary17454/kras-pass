# Four-Peer Crate Flow: Scope-Limited Qualification

Source: `d36ee9294a3886923318f6109a87083b44c27b1c`.
No application, fixture or server source changed during either run.
Four separate headless Godot processes used the actual WebSocket room service
on an ephemeral `127.0.0.1` port, with isolated test saves and no production
credentials. Inputs were scripted; this is not four human/device acceptance.

Single match: exit zero, all peers agree on scores `[35,15,20,14]`.
Host and one guest reconnect successfully. Guest world snapshot counts are
1088, 1107 and 1107. Maximum sampled server loop delay is 94 ms.
Evidence root: `kras-network-smoke-XDkm4a` in the macOS temporary directory.

Three-match tournament: exit zero, all peers agree on round histories,
final points `[12,5,8,9]`, cups `[2,0,1,0]`, champion slot zero and
`complete=true`. Host and one guest reconnect successfully. Guest world
snapshot counts are 1665, 1684 and 1684; maximum server loop delay is 102 ms.
Evidence root: `kras-network-smoke-vkb4Sl` in the same temporary directory.
All eight client stdout files pass the strict runtime log guard.

## Important Limitation

The network peer fixture currently overrides Crate Smash to 15 seconds
instead of the authored 75 seconds, with two rounds per match. These runs
qualify four-peer state flow/reconnect/results agreement only, not sustained
authored-duration network gameplay. The natural balance sample uses full
duration but is local simulation, not a replacement for that missing test.
Authored-duration peer/process/CI budgets must be extended together before
using this fixture for the sustained network release gate. Do not shorten
gameplay to fit the old test deadline or call the current fixture production
network qualification.

Captured runner stdout and server timings are under
`docs/qa/crate-four-peer-flow-2026-10-08`. No client saves or session tokens
are included. Loop-delay values are retained, not described as phone FPS,
Internet latency, thermal or battery evidence.

Core run 37765555402 is terminal success for parent source
`8c52fb3b0e322f10a05e04e90d9fcf662ba2a1f4`, not the later crate fixes.
Production online remains disabled; no production state changed. No local
Xcode archive, Apple upload, processing or review submission occurred.
