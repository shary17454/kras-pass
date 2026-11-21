# Blast Ball Network Tournament Qualification

Tested source: 4e04d9929cab68520aa623bcaddce36ec65cc7d7.
Branch: fix/kras-blast-survival-margin; runtime fix 3f1823a.
Command: GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js
--game=blast_ball --tournament (from server).
Exit: 0. No GDScript failure or leaked-instance marker matched the runner guard.

## Actual Process Results

A real loopback WebSocket server and two, then four, actual headless Godot
processes completed tournaments. The test temporarily loses a guest's transport
and drops the host's first result upload, so both gameplay and pending-result
reconnection paths must recover before the runner accepts completion.

Two humans plus two Bots:
- Four matches completed: three ordinary rounds and one real final tiebreak.
- All clients agreed on final scores [2,4,8,6], points [6,6,11,11],
  cups [1,1,3,3], champion slot 2 and tie_attempts=1.
- Host and guest both reported restored connections.

Four humans:
- Three matches completed with no final tie.
- All clients agreed on final scores [4,2,8,8], points [11,8,8,6],
  cups [2,1,1,1], champion slot 0 and complete=true.
- Host and the deliberately disconnected guest restored their connections.
- Guests received 1661, 1661 and 1635 world snapshots.

Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-b5W5PH.
Raw runner log: /tmp/kras-blast-fixed-network-tournament.log.

## Retained Timing Limitation

Maximum Node monitorEventLoopDelay was 406ms. A separate 100ms sampler recorded
its worst interval as 390.273ms elapsed, 290.273ms overdue and 0.622ms process CPU.
The slowest resume handler measured 217.913ms wall time versus 3.879ms CPU.
The slowest snapshot handler measured 106.340ms wall time versus 2.424ms CPU.
These measurements suggest scheduling or blocking outside sustained JS CPU as
a possibility; they do not prove the root cause. Do not discard this run or
certify connection smoothness from its successful completion.

Raw timing is retained in blast-network-tournament-timing-2026-10-07.json.
No unrelated process was killed to improve the measurement.

## Scope

Network fixture rounds use short duration overrides. Full natural-duration
balance is separately recorded in blast-survival-margin-2026-10-07.md.
This test covers one minigame, a loopback link, scripted inputs and points-mode
tournaments, not all 39 Internet games, physical multiplayer, all tournament
presets, rendered FPS, battery or heat. Server restart/room persistence and
native production Apple authentication remain separate acceptance requirements.

No main merge, Railway deployment, account access, archive replacement, upload
or Apple review submission occurred. Existing archive 110 lacks this runtime fix.
