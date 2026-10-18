# Current Four-Peer Tournament Qualification

Source: `ba3f9f816195516bdba484bd0745f57815675822`, clean feature branch.
Godot 4.7.1 official, imported runtime `/tmp/kras-tank-pursuit-check`.
Runtime fingerprints inspected during and after the peer runs matched:
`dfd58377f9b77ee3f17031c1492a0edd1401d4ea60a64a677a549205fd035e11`.
The imported server directory matched the checkout (excluding node_modules).
No source changes were made during these tests.

## Completed Scenarios

Both existing `server/network-smoke.js` scenarios used a real loopback
WebSocket service and four Godot peer processes, with automated test inputs.
Both exited zero; all eight individual peer stdout logs passed strict Godot
log guards. These are two separately completed peer groups, not eight players
in one room.

1. Mixed points tournament, seed 17, random_no_repeat: hurdle_dash,
   goal_guard and ring_rumble each ran once. All peers agreed on every round
   result, arena history and final tournament state. Points were [8,7,12,8];
   champion slot 2. The host and one client restored transport/session state.
   Other two peers stayed connected. No final tiebreak was needed.
2. Team-tournament tiebreak fixture, seed 17: three duo_clash matches using
   the fixture's equal round-points policy produced [3,3,3,3]. The real
   tournament transition automatically launched duel_pit. All peers completed
   four matches and agreed on one final champion, slot 0, with one tie attempt.
   The host and one client reconnected again. No winner was injected into the
   round result to bypass the actual final.

Commands, executed sequentially in the imported server directory:

```sh
GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js --tournament --mixed-playlist --rotation=random_no_repeat --humans=4 --seed=17
GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js --game=duo_clash --tournament --duo-tiebreak --humans=4 --seed=17
```

## Scope And Evidence

Seven match instances, four distinct games: this is not all-39 network QA.
Fixture durations are overridden for bounded smoke tests. This is not a
full-length balance campaign, public-room UI test, iOS touch/gamepad test,
internet latency test or long-run thermal/energy acceptance.
The service is loopback, enabled specifically for the fixture without
production credentials. It does not attest Railway DB/auth/TLS/callback URLs.

Raw peer logs, isolated save fixtures, server-timing reports, controller stdout
and structured summaries are retained outside Git in
`../qualification-network-current-2026-10-10/`.
Observed server-loop maxima (24 and 41 ms) are not GPU frame-time, mobile FPS
or performance acceptance metrics.

At inspection, older-source balance run 38018326003 had 19 completed game
simulations, two running and 18 queued, despite its overall queued state.
It was not cancelled. Completed job status alone does not mean empty balance
flags; its source 15279bf is not this source. Current Core run 38020374703 was
still in progress when checked; no terminal success was assumed.

The Tank difficulty warning, complete product backlog, current all-game
qualification, native device/controller QA, production gates and exact-source
signed release remain open. No game READY, stage DONE, main promotion,
Railway deployment, Apple upload or review submission is claimed here.
