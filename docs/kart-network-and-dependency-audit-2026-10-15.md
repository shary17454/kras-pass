# Kart network and dependency checks - 2026-10-15

Status: selected local evidence; Stage 0 QA_PENDING / MERGE_PENDING.
Source at execution: 4a9fd49c3f43a5f0730188a59874b3959d0fcad9.
Frozen gameplay fingerprint before/after:
`42a6fc20cd43415a36eb13d70d645b783b0afce52b4198c03d1f2c1a7bc65476`.
No code or test changes overlapped the campaign.

## Actual network race

```
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=kart_sprint --humans=4 --seed=510174
```

PASS, exit 0, real loopback service and four independent Godot processes.
One match on circuit_loop, configured with two internal rounds and three laps.
Host telemetry includes both round 0 and round 1. KartController does not use the
visible round clock; progression is tied to lap completion, with a separate
generous watchdog. No watchdog termination was reported in this run.

All peers agreed on aggregate scores `[4876,4235,4238,4191]` (lower wins) and
race-start seed 510174. The shared initial grid had four unique, finite positions:

```
[17.8999996185303, 1.29999995231628, -1.39999997615814]
[14.6999998092651, 1.29999995231628, -1.39999997615814]
[16.2999992370605, 1.29999995231628, -1.39999997615814]
[13.1000003814697, 1.29999995231628, -1.39999997615814]
```

The harness checked required lap completion, physical boost/rescue evidence,
consistent start assignments, movement and result delivery. Host ID 1 and guest
ID 2 reconnected. All eight engine/stdout logs passed the strict runtime guard.
Guests received 1463-1482 presentation/world snapshots.

The initial-grid history is per match, not a complete visual check of each
internal-round guest reset. Host telemetry shows the second-round grid reset.
Final scores were completed-race values, not unfinished billion-point sentinels;
the separate result-boundary unit tests cover sentinel bounds. In-progress
telemetry contains the unfinished sentinel in the replicated race state.

The source fixture's default duration override does not terminate lap races:
uses_round_clock() returns false. The process deadlines remain test safety limits,
not a substitute for completing the selected laps.

## Performance limits

Host logs record a cumulative frame-gap maximum of 300 ms, already present during
initial countdown/loading. Server loop maximum reached approximately 40 ms. These
must not be represented as proof of steady 60/120 FPS, no stutter, battery life,
thermals or production latency. This was one desktop, scripted inputs and one
circuit, not physical controllers/devices or every racing world.

## Runtime npm dependency audit

Executed npm audit --omit=dev --json against the installed server production
dependency graph. A second recorded invocation captured stdout separately from
npm's upgrade notice so the retained artifact is valid JSON. Both exited 0 and
reported zero known advisories at all severities. No packages or global npm were
updated and no production data/credentials were used.

Scope is the two installed runtime dependencies in server/ (jose and ws), not
root deployment devDependencies, native Godot/iOS binaries, asset rights or
custom application security. This is a point-in-time registry result, not a
guarantee against undisclosed vulnerabilities or full security approval.

## Evidence

Sibling ../qualification-kart-network-2026-10-15/ contains eight peer logs,
server-timing.json and npm-runtime-audit.json. No private save profiles were copied.

SHA-256:

- Timing JSON: `e2503aa23952880c3d40877fc4e4e7df85c9e678973cef21280da9a8582147e6`
- Audit JSON: `12931fe186a1d5341d0bd56a90726249c7208945f5b9168701ba8b1af5ce8dc3`

No new full Godot/server suite count is claimed here; application source remained
unchanged from the previous 427673-assertion/276-server-test qualification.
Other games/maps/variants, AI balance, physical-device QA and production backup/
restore/rollout and native connectivity remain open. No main merge, Git push,
Railway mutation, signed Xcode Archive, upload or Apple review submission occurred.
