# Platform Warning Jump Qualification

## Implementation

Runtime commit: `61fc28c0eac2e3179b5e67f2b2137920bbfbf0e2`.
Base is the previously integrated platform-routing correction; this branch
does not alter other minigame brains, movement speeds, character stats,
collapse schedules, scoring, durations or test thresholds.

Crumble Court bots can now request the same jump action available to humans.
They only react to visible WARNING ground beneath themselves, after their
configured reaction delay, and only while physically grounded. Existing
`edge_awareness` controls the chance of correctly responding. Disabled jump
capability is respected. Hidden or solid ground loses warning observation
credit; round restart clears warning and routing state. No tile timer is read.

## Regression And Natural Samples

The real-collider fixture initially did not settle onto the floor; correcting
its starting height and allowing twelve physics frames produced a valid red
test: 14 pass, two fail for missing jump request/impulse. After implementation
and delayed-observation coverage, the focused suite passed 19 assertions.
It checks actual native floor contact and the ordinary Fighter jump impulse,
not a mocked `is_on_floor()` result. Shared visibility passed 2085 assertions.
Compilation passed for all 384 scripts.

Final full pipeline, unchanged runtime source, completed with exit 0:
`GODOT_BIN=/opt/homebrew/bin/godot sh tools/check_party.sh`.
Log: `/tmp/kras-platform-delayed-jump-full.log`.
Artifact directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.i7pQn3`.

- Full suite: **360639 assertions passed**, 214.4 seconds.
- Inventory: 424 resources, 21 autoloads, 27 routes, eight characters, no issues.
- Actual AI three-lap race regression passed.
- Six separate boss regression scenarios passed.
- Stability: 39 default-arena matches, zero failures; ordinary timed windows
  shortened, real race laps retained. This is not the natural balance campaign.
- Five-second settled Godot static memory after graphics cache release:
  441302723 bytes. Retained memory remains unresolved; not RSS/GPU/phone proof.

The earlier `/tmp/kras-platform-jump-full.log` pipeline ran while the reaction
delay revision was being made and is superseded by this frozen-source run.
Its count must not be used as evidence for the final implementation.

Natural Crumble Court samples retain the authored 90-second window and actual
elimination ending, with 24 baselines, 16 paired difficulty matches and two
mutator/chaos matches per seed offset. All completed and log guards passed.

| Source | Seed Offset | Mean Seconds | Expert Share | Slot Bias | Character Bias |
| --- | ---: | ---: | ---: | ---: | ---: |
| Routing-only parent | 600000 | 6.3083 | 0.6250 | 0.0833 | 0.0833 |
| Experimental immediate jump | 600000 | 8.6340 | 0.5750 | 0.2083 | 0.0833 |
| Final delayed jump | 600000 | 6.3924 | 0.5750 | 0.0417 | 0.0833 |
| Final delayed jump | 900000 | 6.3375 | 0.6000 | 0.0833 | 0.0833 |

Final reports:
`/tmp/kras-platform-delayed-natural-report/report.json`,
`/tmp/kras-delayed-jump-independent-report/report.json`.
Both have no automated flags. The short round is NOT solved: proper reaction
delay removes most of the experimental immediate-jump survival increase.
Neither this result nor an empty flag list qualifies the game as READY.

## Actual Local Peer Checks

`server/network-smoke.js --game=crumble_court --seed=438683058` passed:

- Two human engine processes plus two bots, host and client reconnect,
  matching scores `[6,10,10,14]`, 671 client worlds, server loop maximum 25 ms.
- Four human engine processes, host and one client reconnect, matching scores
  `[4,8,12,16]`, 681/700/700 client worlds, server loop maximum 105 ms.

Logs: `/tmp/kras-delayed-jump-two-peer-authorized.log`,
`/tmp/kras-delayed-jump-four-peer.log`; runtime guards passed.
These are temporary localhost WebSocket services with automated engine inputs,
not four real people over Internet or phone latency/FPS qualification.
The initial sandbox attempt could not bind localhost (`EPERM`); the authorized
local invocation completed. An initial Godot invocation without an explicit
writable log crashed opening its user log; isolated explicit-log reruns passed.
Sandboxed runs also reported the macOS system-CA access error; no TLS exchange
or CA-system health is inferred from the headless gameplay tests.

## Production And Release Boundaries

Railway deployment `02e0e4d5-1c8f-4e06-8c6a-8951e656432e` is SUCCESS from
GitHub `shary17454/kras-pass`, main
`734f08de9e42d1b7130e6c07ada621f1a1a52761`, not this new branch.
Effective health gate is `/health`, timeout 100 seconds; `/data` mounted.
Fresh health returned `ok=true`, `authentication_ready=true`,
`multiplayer_enabled=false`. Six returned startup log entries were informational;
this small sample is not proof of all production routes or historical errors.

Main CI run `37386716943` verified core, ring and goal networking jobs successful
at inspection; remaining network matrix incomplete and balance skipped.
It does not prove the new branch's CI or all release gates.

Fresh local Keychain inspection finds the existing requested Apple Distribution
identity, team 4HM66AD594. Xcode 27.0 build 27A266a is installed. No P12 imported,
password requested, certificate changed, archive built or Apple upload/submission
performed. Current tracked Godot config version remains 1.1.9 while iOS export
is 1.1.10 (107); final release numbers require App Store Connect refresh and
alignment before archive creation.

Open gates include the seven historical balance findings documented in
`all39-natural-campaign-2026-10-06.md`, round pacing, retained memory,
Internet/device multiplayer, physical portrait/landscape and thermal/battery QA,
remaining product requirements, and exact-source Distribution release checks.
Full parent campaign must not be relabelled as a new-branch campaign.
