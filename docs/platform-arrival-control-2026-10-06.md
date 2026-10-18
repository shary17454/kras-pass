# Platform Arrival Control Qualification

## Source And Reproduction

Branch: `fix/kras-platform-arrival-control`, stacked on PR113.
Parent: `3e4045cc83ca2145c8e31a6f8fdf6a66317f3658`.
Frozen runtime: `c617662e527a57175ff830b99d4a67479f6cf839`.

Tracing a natural round showed a platform bot holding full movement input
near the centre of its selected tile. The input stays latched until the next
decision, so it can overshoot that tile into a missing neighbour. The new
fixture uses a real grounded Fighter collider, ordinary walk integration and
the held input over 28 physics ticks. Before the correction: 31 assertions
passed and four failed. After: all 35 pass.

The bot now scales analog input by planar distance over its normal maximum
decision horizon plus its own braking distance. Current speed modifiers and
ordinary ground/air acceleration are included; distant targets retain full
input. No fighter speed, acceleration, reaction timer, difficulty profile,
opponent information or floor timing is changed. Visibility remains required
for the target and route origin. This is input control, not a physics boost.

An initial red invocation used unsupported `--filter=` and therefore selected
all suites. It was explicitly stopped with exit 130; it is not a completed
full-suite result. The corrected `--suite=platform_ground_routing` invocation
reproduced the four failures with exit 1 before the runtime edit.

## Full Source Qualification

Godot 4.7.1 official, macOS, fixed headless simulation 60 Hz:

- Focused routing: 35 pass, `/tmp/kras-arrival-green.stdout`.
- Release gate: exit zero, `/tmp/kras-arrival-final-release-gate.stdout`.
  Directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.nn2zQ7`.
  390 scripts compile. Inventory: 434 resources, 22 autoloads, 27 routes,
  eight characters, zero structural issues. Full suite: 366157 assertions in
  306.7 seconds. Three-lap regression and six boss checks pass. Stability:
  117 matches, zero failures. Settled static memory: 133587705 bytes, not RSS
  or GPU memory.
- Server: 192 pass, zero failures, zero skips, with the final suite's six
  actual world captures. `/tmp/kras-arrival-final-server.stdout`.
- Runtime guards and `git diff --check` pass. Existing sandbox CA enumeration
  diagnostics are allowed by the guard, not evidence of valid production TLS.
  The stability fixture deliberately simulates an OS memory warning.

Tracked source remained unchanged through the final gate, natural campaigns,
rendered probes and network smoke. The first natural campaign started after
the edit but before its commit; its working tree was identical to the frozen
runtime subsequently committed. Documentation is added after every owned
qualification process is terminal.

## Natural Pacing And Difficulty Finding

Each campaign completes 24 baselines, 16 matched character/difficulty rounds
and two mutator/chaos samples: 84 matches across independent offsets, with
natural elimination ending and authored round windows.

| Offset | Mean Seconds | Expert Share | Slot Bias | Character Bias |
| --- | ---: | ---: | ---: | ---: |
| 600000 | 11.911806 | 0.443750 | 0.083333 | 0.125000 |
| 900000 | 11.948611 | 0.518750 | 0.125000 | 0.125000 |

Reports: `/tmp/kras-arrival-natural-report/report.json` and
`/tmp/kras-arrival-independent-report/report.json`.
Both processes exit zero and console guards pass, but BOTH reports flag
`expert bots no better than easy`. Non-critical review flags do not fail the
simulator process. The first Expert share is below 0.5; the second is above
0.5 but still below the existing review threshold. Thresholds and flags were
not changed. These results do NOT establish fair difficulty progression.

Before this correction, the same two seed sequences averaged 8.014583 and
7.797222 seconds on fec74a6. Arrival safety and pacing improve in these
samples, but the game remains NEEDS_BALANCE/NEEDS_POLISH. Authentic play,
safe movement during jumps and difficulty strategy need further review.

## Rendered Portrait And Landscape

Actual native macOS windows: Metal 4 / Mobile renderer, Apple M5, default
quality High, four Expert bots, seed 11. The existing performance probe uses
an explicit 60-second round override and uncapped rendering; these are NOT
natural campaign results, a 60/120-FPS phone qualification or touch QA.

| Window | Samples | Live Seconds | Mean Frame | P95 | Worst | Build |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 720x1280 | 1066 | 10.0 | 8.46 ms | 9.29 ms | 78.262 ms | 3552 ms |
| 1280x720 | 1068 | 10.0 | 8.43 ms | 9.26 ms | 59.405 ms | 3426 ms |

All four fighters move; maximum displacements are 19.38/14.61/9.76/22.43
world units in each deterministic sample. Both have two frames above 25 ms.
Nodes return from play to 51, matching the starting count. Console guards
pass. Screenshots were viewed and show the live arena, surviving fighters,
warning tiles, player symbols, Arabic objective and HUD without a blank
canvas. Desktop automatic touch controls are off; four-hand phone ergonomics
are not tested. Screenshot dimensions match the requested windows.

Evidence: `/tmp/kras-arrival-render-portrait.{stdout,log,png}` and
`/tmp/kras-arrival-render-landscape.{stdout,log,png}`. The portrait probe's
single-line 118 FPS and landscape 119 FPS are uncapped native Mac results,
not guarantees about phone performance, battery or temperature.

## Actual Local Network And Unresolved Delay

`network-smoke.js --game=crumble_court --seed=438683058` ran after the heavy
qualification processes had finished; exit zero and log guard pass.
`/tmp/kras-arrival-final-network.stdout`:

- Two automated human processes plus two bots move and reconnect; scores
  agree `[4,8,14,16]`; client receives 1031 world snapshots.
- Four automated human processes move; host and one client reconnect; scores
  agree `[4,8,14,14]`; clients receive 690/709/709 world snapshots.
- Event-loop monitor maximum: 388 ms. Separate 100-ms sampler's worst delay:
  272.935 ms, with only 0.474 ms process CPU over the 372.935-ms interval.
  Maximum snapshot handler: 82.912 ms wall / 0.436 ms CPU; maximum input
  handler: 81.961 ms wall / 0.125 ms CPU.

Timing report:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-gEVWWe/server-timing.json`.
Low CPU does not identify the scheduling/blocking cause. A later process
inventory showed no active Godot/Xcode process, not a profile during the
stall. Do not call this network-latency qualification or hide the delay.
This test is not four people or production Internet multiplayer.

## Release State

Fresh origin/main remains `062a40992b92958573e28e19d8c8c1840560797a`.
Railway health reports ok/authentication_ready true and multiplayer_enabled
false. This branch is not merged or deployed. The new authored timer contract
still needs coordinated server/client rollout before online activation.

No current-source signed archive, Apple upload, processing or review occurred.
The final release must use local Xcode 27, not Xcode Cloud. The existing Apple
Distribution identity must be reverified in Keychain without P12 import.
Open requirements still include difficulty/pacing, authentic 39-game and
device QA, battery/thermal evidence, production networking, remaining product
acceptance, source integration and exact-source signing/upload/review.
