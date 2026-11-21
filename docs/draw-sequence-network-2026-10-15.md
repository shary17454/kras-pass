# Reaction event identity and selected network checks - 2026-10-15

Status: selected local functional qualification; Stage 0 QA_PENDING / MERGE_PENDING.
Base commit: `4b1fda4b665980fa9ffb5c0b3e914d7090eceeba`.
Branch: feature/kras-online-random-rotation.

## Defect found during actual network testing

DrawReplica rendered stage, prompt number, response order and locks, but did not
copy the four event sequence counters into the guest controller. Audio used the
replica's own counters, masking the inconsistent public controller state.
The scripted peer responds once per signal identity; guests therefore answered
only the first observed identity, despite later prompts being visible.

The previous smoke required only one signal and one accepted response. Its PASS
did not prove repeated-prompt behavior or timing fairness. The first score array
was `[12,2,2,2]`. Treating that alone as proof of transport-caused host advantage
would be unjustified; stale event identity was a concrete confounder.

The regression reproduced three failures: correct/wrong counters stayed zero
and quiet reconnect retained an old signal identity (87 passed / 3 failed).
The retained production change copies each validated event counter into the
controller during rendering. Freshness/duplicate-audio handling is unchanged.
The focused suite then passed 90 assertions and its strict test log guard.

Strengthened the real peer test to compare all four counters with the host world
and require responses to at least two distinct prompts in ordinary matches.
First-response tournament deciders remain exempt from the two-prompt minimum.
Accepted prompt identities are emitted in the synthetic result evidence.

No score, input transport, wait clock, false-start penalty, local same-tick tie,
tournament rule or hidden-timing protocol field was changed.

## Rejected window experiment

Before isolating the counter defect, tested a 100ms online arrival tie window.
An initial fixture tried to set up an ONLINE scene without a live session and
hit a Nil-controller Script Error. The log guard correctly rejected it despite
the runner's partial ALL TESTS PASSED output. The corrected fixture isolated
controller context after local scene setup; it gave 110 passes / 25 failures on
original code and 135 passes with the candidate policy.

The actual network candidate still produced `[12,3,3,3]` and did not establish
fairness. That experiment did not repair the stale identity. The window and all
of its new fixture code were removed, with original Quick Draw controller and
local lifecycle suite checked byte-for-byte against HEAD. Rejected copies/logs
are evidence only in the sibling qualification directory, not release source.
There is no retained 100ms scoring rule or arbitrary latency compensation.

## Real four-process runs

Godot 4.7.1 and Node local loopback WebSocket service, isolated HOME and synthetic
save roots. Each command used four independent processes with scripted inputs:

```sh
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=symbol_echo --humans=4 --seed=510180
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=rising_tide --humans=4 --seed=510181
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=quick_draw --humans=4 --seed=510182
```

Echo/tide/original-draw ran on the base fingerprint
`cd39a5b2766c1d8c93e50e1824034ca2f4de306e014aa1ffdf67fddea13663bc`.
The final draw run used
`3bb6522645d38973ce59b5d0176a119b0dc7c245d1d8b04afc01c8af503b6014`.
No code/test edits overlapped a run. All 70 server files and the starting peer
harness/network source were matched against the committed base before testing.

| Run / arena | Agreed scores | Guest world snapshots | Evidence scope |
| --- | --- | --- | --- |
| symbol_echo / echo_hall | [42,36,36,43] | 1088-1107 | cues and accepted observed answers; final guest progress/state; no retained private sequence |
| rising_tide / tide_spire | [4,4,4,4] | 974-994 | rising water, authoritative submersion/elimination, matching guest level |
| original quick_draw / draw_stage | [12,2,2,2] | 1088-1107 | loose one-response check only; incomplete multi-prompt evidence |
| fixed quick_draw / draw_stage | [18,11,12,7] | 1088-1107 | each peer recorded accepted prompt identities 1 through 7; all event counters match |

All four runs exited 0 with PASS and their 32 engine/stdout logs passed the
strict runtime guard. Host ID 1 and guest ID 2 reconnected in every run.
The tide fixture deliberately circles on the low platform, so equal drowning
scores are an expected tie, not evidence of selecting a unique champion.
The final reaction run delivered more complete response cycles; raw before/after
scores are not a paired fairness or reaction-speed benchmark. Host arrival
advantage under real Internet latency is not qualified or claimed fixed.

These are shortened fixture matches, not natural balance or human/controller
tests. Echo's private-sequence assertion inspects guest state/final target world;
do not describe it as a packet capture of every possible state.

Console loop observations reached 30ms (echo), 23ms (tide), 60ms (original/final
draw). Cumulative host frame gaps were 364/367/359/339ms respectively, including
startup/phase costs. None qualifies sustained FPS, phone thermals or battery use.

## Source and evidence

Changed source/test bytes matched between checkout and tested runtime:
- src/net/draw_replica.gd: `24a3bec87eeb6d69f86aa5f4221eedcfd2c6dfd0e728f08bad291ec5b08c59f0`
- tests/network_peer.gd: `52d3976b0b8bd9cd4cb90cca85934d1369083afbe553008f5f7feb49c047d244`
- tests/suites/test_draw_network.gd: `d61fe8a94b60aa255cc6d491b192d0383c24442ffd37e709d6ec6e1f04c7a0e7`

Sibling `qualification-draw-sequence-2026-10-15/` preserves synthetic logs/timing
JSONs, failed attempts and rejected policy copies; private save directories were
not copied. Final draw timing JSON SHA-256:
`57eb489e1bc66290dafcf45c5797921bdceb0b9df342b1fd437310ccbf3a8317`.

All 466 scripts compiled, exit 0, strict runtime guard passed. The full suite
passed 427740 assertions in 244.3s, exit 0, strict test log guard passed.
The four ERROR entries were inspected and originate from the intentional failed
save fixture and three router-recovery tests, not ignored production errors.
Full log SHA-256:
`e847147d608980f7096890ec69e6db2149bc9892f427f23ea4b1fdba96c54637`.
No source/test edits overlapped full qualification; the final fingerprint stayed
3bb652. No new server-suite run is claimed; server bytes remain unchanged.

No merge, push,
Railway mutation, fresh iOS Archive, upload or Apple review submission occurred.
All-game/physical-device/network-latency/balance and production gates remain open.
