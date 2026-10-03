# Kart Sprint smoke session budget

Source: `fc982369db98091b79fbd3cb3134abef4f026f03` on
`feature/kras-race-smoke-budget`. This is a test-harness change only: no game
duration, lap count, finish condition, physics, items or scoring was changed.

The older CI run `37081719185` completed the first ordinary three-lap race at
94.63 simulation seconds and then expired the generic 150-second peer session
watchdog during its second race. Two full races must fit the session budget;
the fixture must not skip a race, lower its laps or invent a finish.

`tests/race_smoke_budget.json` is now shared by the Godot peer and Node runner.
The ordinary race window is 420 seconds, matching the existing integration
suite's `_match_window()` for races. A final has the existing production
120-second race safety window, with at most three final attempts as enforced
by the tournament server. A 60-second session setup allowance is added.

- Ordinary peer: two race windows plus setup = 900 seconds.
- Tournament peer: three race windows, three final windows and setup = 1680 seconds.
- Node: the corresponding peer allowance plus 60 seconds for transport/cleanup
  = 960 or 1740 seconds wall time.
- CI: two ordinary groups and three tournament/final groups total 7140 seconds;
  including 10 minutes setup fits the 130-minute bounded job allowance.

These are failure watchdogs, not forced game completion. Every original real
lap, rescue, boost, guest ownership, score agreement and reconnect assertion
remains enabled. Other games retain their previous watchdogs.

## Focused checks

- `node --test race-smoke-budget.test.js`: one test passed, exit zero. Checks
  both peer and Node allowances and the aggregate CI allowance.
- `/tmp/kras-race-smoke-budget.log`: four assertions passed, exit zero.
- `/tmp/kras-race-budget-compile.log`: all 322 scripts compile, exit zero.
- `node --check server/network-smoke.js` and `git diff --check`: passed.

## Two clients plus bots: PASS

Command: `node network-smoke.js --game=kart_sprint --humans=2 --seed=9614`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-UsvbOB`.

Both real Godot peers completed the two-round session and reconnected, including
the dropped host-result recovery. Scores matched at `[4935,10797,1999996817,1999996028]`.
Both human competitors completed their laps; unfinished bots were ranked behind
the human finishers using the unchanged production rule. This is not a claim
that all bots finished. The guest received 2646 world snapshots and passed
physical rescue/boost and guest ownership checks. Node exited zero. Server
loop delay reached 2433 ms, so this is not a production-latency certificate.

Runtime and publishing copies of the five affected harness/budget files were
SHA-256 compared before the run. The old CI failure used seed `487119885`, as
verified from job `111083481085`; its fresh result is recorded below.
Tournament/final qualification remains required; four clients are recorded below.

## Previous CI seed with two clients: PASS

Command: `node network-smoke.js --game=kart_sprint --humans=2 --seed=487119885`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-iw0Btg`.

The complete two-round session exited zero. Both humans completed their laps,
both peers reconnected and agreed on `[4905,5396,1999998227,1999998424]`; the
guest received 1645 world snapshots. As above, bot sentinel scores are not
claimed as bot finishes. The existing boost/rescue and guest baseline checks
passed. Server loop delay reached 1875 ms. This is a current-source macOS pass
at the older failure's seed, not a claim that the older Linux job or current
Linux CI has passed. Four-client and tournament/final qualification is separate.

## Four clients at the previous CI seed: PASS

Command: `node network-smoke.js --game=kart_sprint --humans=4 --seed=487119885`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-onpPW9`.

All four real Godot clients completed both three-lap rounds, with matching
aggregate scores `[5276,10505,6986,6945]` and no unfinished human sentinel.
The host and one guest reconnected. Guests received 2716-2735 world snapshots;
existing physical boost/rescue, baseline and collision-ownership checks passed.
Node exited zero. Server loop delay reached 3173 ms. This is functional
qualification for this map/seed, not device FPS or production latency evidence.

Fresh Linux CI, tournament/final and the remaining release gates are pending.

## Two clients plus bots tournament: PASS

Source: `eefbf7c59da03a342d4e1e4a23c078bf4df2255a`.
Command: `node network-smoke.js --game=kart_sprint --humans=2 --tournament --seed=487119885`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-u61oRz`.

Both real peers completed three tournament matches and reconnected. Final
match scores were `[2455,3118,999999113,999999013]`, tournament points
`[15,9,3,6]`, cups `[3,0,0,0]`, champion slot 0 and no tied final. The guest
received 3248 world snapshots. Node exited zero; all existing physical
boost/rescue, actual human finish and guest ownership checks passed. As in the
ordinary sessions, unfinished bots are not claimed as finishers. Server loop
delay reached 4643 ms, so this is not production latency or FPS evidence.

## Four clients with tied race final: PASS

Source: the same `eefbf7c` head.
Command: `node network-smoke.js --game=kart_sprint --humans=4 --tournament --race-tiebreak --seed=487119885`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Z7dYIS`.

Every actual Godot peer completed three ordinary three-lap races plus the
one-lap final. All four agreed on final scores `[1137,722,1715,1187]`, champion
slot 1, points `[3,3,3,3]`, unchanged cups `[1,1,1,0]`, zero final awards and
one tie attempt. The host and one guest reconnected. Guests received 4294-4313
world snapshots; all finish, collision baseline, replica ownership and final
award/cup checks passed. Node exited zero. All four slots began this final as
contenders; spectator-only final qualification is separate. Server loop delay
reached 2984 ms, not a performance certification.

These local successes do not imply all 39 online games are production-ready.
The current Linux matrix and release/device/production-service gates remain
separate, and no App Store submission was performed.
