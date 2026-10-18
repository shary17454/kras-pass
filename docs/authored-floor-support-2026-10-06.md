# Authored Floor Timing And Supporting Contact Qualification

## Frozen Source

Branch: `fix/kras-authored-tile-timing`.
Parent: `db1ccaca8f37bd93ace65307a12a669507dbad97` (PR112).
Timing commit: `9f66ca65034334937367b7f109a7d47883866e27`.
Final runtime: `fec74a6a2ecc1c07847691ff18a631e3e5623f97`.
Tracked source stayed unchanged throughout final qualification. This document
is added only after all owned qualification processes finished.

## Reproduced Defects And Changes

The arena builder ignored authored crumble delay and respawn settings.
An arena configured for 2.4 seconds and a three-second return used the global
0.9/6 values, collapsed prematurely and retained wrong values after reset.
The red fixture passed 164 assertions and failed five. The builder now applies
bounded authored values only to crumbling floors; ordinary floors retain
their existing behavior. The public warning ceiling is 2.4 seconds. The
authored Crumble Court delay changes from 0.9 to 2.4; respawn remains six.

An actual physics probe then reproduced a separate edge-support defect.
At position `(1.1,-0.01207,0)`, the nearest tile was FALLING but the player's
capsule was still grounded on a neighbouring WARNING tile. The route selector
returned null and stopped moving. Probe evidence:
`/tmp/kras-ground-contact-scene.stdout`.
The permanent regression failed two of 28 assertions before the correction.

The platform brain now falls back to its own current supporting collision
when the nearest visible tile is unstandable. Contact must be a floor normal,
within the live capsule's reach, in this arena, visible and standable. Hidden,
foreign, wall, airborne and stale teleport contacts cannot form a route.
Reaction delays, speed, character attributes and hidden fuse information are
unchanged. The prior first-step warning penalty remains intact.
Scratch probes were removed; the physics regression remains in the suite.

## Snapshot Compatibility

Both the client Crumble validator and server accept WARNING timers through
2.4 seconds. Tile row shape/count are unchanged. Color Stand explicitly keeps
its separate 0.9-second limit, with rejection tests on both sides.
This is a semantic relaxation, NOT proof of compatibility with an old server
that accepts only 0.9. Updated clients and Railway must be deployed together
before enabling production online play; this branch does not enable it.

## Final Runtime Qualification

Godot 4.7.1 official, macOS headless, fixed simulation 60 Hz:

- Arena tiles: 169 assertions, `/tmp/kras-authored-timing-green.stdout`.
- Crumble replica: 2515, `/tmp/kras-authored-crumble-network.stdout`.
- Color replica: 431, `/tmp/kras-authored-color-network.stdout`.
- Final routing: 28, `/tmp/kras-supported-route-green.stdout`.
- Shared AI perception: 2091, `/tmp/kras-supported-route-visibility.stdout`.
- Final release script: exit zero,
  `/tmp/kras-supported-final-release-gate.stdout`.
  Evidence directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.5gXvOW`.
  390 scripts compile; 434 resources, 22 autoloads, 27 routes and eight
  characters have zero inventory issues. Full suite: 366150 assertions,
  471.3 seconds. Three-lap race and all six boss checks pass. Stability:
  117 matches, zero failures. Settled static memory: 133582837 bytes.
- Server: 192 pass, zero failures and zero skips, using all six actual world
  captures from the final suite. `/tmp/kras-supported-final-server-captures.stdout`.
- Runtime console guards and `git diff --check` pass. Local CA enumeration
  diagnostics are allowed by the existing guard; they are not TLS evidence.
  The stability suite deliberately emits its simulated OS memory warning.

The timing-only source separately passed 366144 assertions and 117 matches;
that older result is not substituted for final contact-routing qualification.

## Natural Campaigns And Remaining Pacing

Each final-source campaign completed 24 baselines, 16 matched difficulty
rounds and two mutator/chaos matches, retaining natural win conditions and
authored round windows: 84 completed matches across two independent offsets.

| Seed Offset | Mean Seconds | Expert Share | Slot Bias | Character Bias |
| --- | ---: | ---: | ---: | ---: |
| 600000 | 8.014583 | 0.587500 | 0.041667 | 0.208333 |
| 900000 | 7.797222 | 0.577640 | 0.083333 | 0.083333 |

Reports: `/tmp/kras-supported-natural-report/report.json` and
`/tmp/kras-supported-independent-report/report.json`. Both process exits and
log guards pass; both have zero automated flags. This is not statistical
proof of balance or human enjoyment. The timing-only first campaign had a
character-advantage flag (0.25); its independent campaign did not. No flags
or thresholds were hidden or weakened to obtain these results.

The round is still short relative to the intended party-game experience.
The game remains NEEDS_POLISH; this correction does NOT complete pacing QA.

## Actual Local Network Processes

Final `network-smoke.js --game=crumble_court --seed=438683058` exits zero with
a passing console guard. `/tmp/kras-supported-final-network.stdout`:

- Two automated human processes plus two bots move and reconnect; scores
  agree `[4,8,17,12]`, client receives 759 world snapshots.
- Four automated human processes move; host and one client reconnect; scores
  agree `[4,8,14,14]`, clients receive 678/700/700 world snapshots.
- Maximum observed service loop delay: 344 ms. This remains a performance
  concern to investigate under representative load, not a latency pass.

This is actual local WebSocket/engine evidence, not four people, production
Internet play, physical-device FPS, battery or thermal qualification.

## Release Boundaries

Local Xcode is verified as 27.0 (27A266a) at
`/Applications/Xcode-27.app/Contents/Developer`; Xcode Cloud is not used.
No current-source signed Archive, distribution verification, Apple upload,
processing, withdrawal or review submission occurred during this work.
No merge into main or Railway deployment occurred.

Open gates include authentic pacing/balance, all-game rendered orientation
QA, physical iPhone/iPad and battery/thermal testing, production networking,
remaining product acceptance, authorized source integration and exact-source
local Xcode 27 signing/upload/review. Existing version/build numbers still
need verified replacement before the final release archive.
