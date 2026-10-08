# PR 215 Completed Job Evidence

Run: https://github.com/shary17454/kras-pass/actions/runs/37720872761
Intended head: `50539cbe5ab83f1482700800ccc90bcf68d97254`.
CI checkout: `ecb6715f181009a84272b89372705baf42df8f2b`.
Both have tree `8d5720c25b6bfdff9efa22eae7c707708afd05ac`.
Downloaded source records have no tracked changes. Later local documentation
and sample-index tooling are not part of this CI checkout.

Retained raw records: `qa/pr215-completed-artifacts-2026-10-08/`.
These are completed jobs, not a claim that the whole workflow completed.

## Core

- Official Godot 4.7.1 on Linux: 423 scripts compiled.
- Inventory: 523 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- Main suite: 391987 assertions passed.
- Stability: three cycles, 117 matches, zero failures.
- Server tests before real world captures: 223 passed, six skipped.
- Server tests after real world captures: 229 passed, zero skipped, zero failed.
- Existing log guards passed all 59 stdout files in the core and first three
  network artifacts; another 15 stdout files passed in Star Rush's artifact.
  Deliberately exercised failing-suite fixtures are not engine aborts; the
  completed positive test summary was required separately.

## Network

Gem Grab, Goal Guard, Ring Rumble and Star Rush each completed short scripted
matches and tournaments with two and four clients. Result arrays have the
expected client counts; all clients agree on scores and completed tournament
state. Host and first guest both report reconnecting in each configuration.
These are automated clients, not physical people or production Internet tests.

All eight timing reports contain zero sampled scheduling stalls. The sampler
records excess delay of at least 100 ms over its 100 ms interval; zero recorded
stalls does not mean zero latency. Maximum snapshot handler wall time across
these reports is 1.106 ms; maximum input handler wall time is 3.139 ms.
This is not an iPhone frame-rate, battery, heat or sustained-load measurement.

Ring Rumble remains tied after three bounded tiebreak attempts and completes
with four shared champions, consistent with the existing tournament policy.
It does not demonstrate a unique Sudden Death winner. Goal Guard's four-client
tournament reports `moved=false` for host and first guest, while the other two
report movement; do not claim every client moved in every fixture.

## Open Gates

At this observation, 35 other network jobs remain queued. The separate
current-source balance campaign 37721855569 has Ring Rumble running and 38
simulation jobs queued. Neither run was restarted or cancelled.

All-game natural balance qualification, physical-device QA, production rollout,
positive native production connectivity, frozen release commit and numbers,
local Xcode 27 Distribution archive, upload, processing and App Review submission
remain unproven. No merge to main, production change or Apple upload was made.
