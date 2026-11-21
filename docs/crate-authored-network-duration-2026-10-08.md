# Crate Smash authored-duration network qualification

## Change

The former network fixture overrode the authored 75-second round with 15 seconds.
Crate Smash now uses `duration_override = 0`, with a shared JSON budget consumed
by Godot and Node: two rounds per match, three tournament matches, up to three
finals, 60 seconds setup and 60 seconds process grace. Peer deadlines are 210/960
seconds; process deadlines are 270/1020 seconds. CI reserves 60 minutes for both
two-peer and four-peer match/tournament groups plus setup. Unrelated fixtures
are unchanged.

## Evidence

Tested the working tree based on `077e49a`, including the budget/fixture changes
in this commit. No gameplay scripts were edited during the run.

- Node budget tests: 2 passed.
- Godot `crate_smoke_budget`: 6 assertions passed.
- Godot `crate_network`: 169 assertions passed.
- Compilation: 430 scripts, successful; strict log guard passed.
- Server tests: 238 passed, 0 failed, 6 skipped. The initial sandbox run failed
  to open a loopback socket (`EPERM`); the local-session rerun passed.
- Real four-process match: `node network-smoke.js --game=crate_smash
  --humans=4 --seed=3904242`, terminal exit 0. All clients agreed on scores
  `[78,23,32,31]`; host and guest 2 reconnected; guest world snapshot counts
  were 3489/3508/3508. All four client logs passed the strict runtime guard.

Evidence paths on this Mac:

- `/tmp/kras-crate-authored-match.stdout`
- `/tmp/kras-crate-budget-scene.stdout`
- `/tmp/kras-crate-authored-suite.stdout`
- `/tmp/kras-crate-budget-compile-local.stdout`
- `/tmp/kras-crate-budget-server-local.stdout`
- `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-PiUPf6/server-timing.json`

Rejected invocations are not counted: launching the Node-based test runner as a
`--script` lacked autoloads; the first compile invocation lacked an isolated
test directory; the sandbox compile rerun reported a system CA access error.
The accepted compile used the scene, isolated test data and the local session.

## Open gates

Maximum observed server event-loop delay was 334 ms. The scheduling probe
recorded stalls, including 258.9 ms excess over its expected sampling interval.
This is an open performance observation, not an iPhone FPS or thermal result.
The clients use scripted human-slot inputs on loopback, not four people or
four Internet devices. Authored-duration tournament, current-source full-suite
and device qualification remain pending. No main merge, Railway deployment,
Apple archive, upload or review submission is proved by these tests.
