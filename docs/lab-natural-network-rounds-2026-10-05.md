# Natural Lab network qualification

Based on `0a60b58f5937ae0f65ea47beb1cd95471a2f869b`. This changes testing
configuration and budgets, not runtime weapon randomness or match rules.

## Retained failure and test scope

CI run 37222295173, intended source
`48b0589c11879a2454ed8f3a926e6507738608f1`, failed the four-player Lab
coverage gate at seed 1302046270. Its final event lanes recorded 35 ordinary
breaks, eight traps, two shockwaves, zero volleys and eight ingots. The strict
weapon/visible-projectile requirement was not met. This older CI failure is
retained in `/tmp/kras-ci-lab-crates-37222295173.log`.

The network fixture shortened Lab rounds from the authored 90 seconds to 15.
It now uses the authored duration, retaining the two-round match, existing
input driver, random weapon selection and every strict observation assertion.
No weapon is injected, no RNG outcome is forced, and no probability is changed.
A local short-round run of the same seed passed; network/input timing is not
claimed to reproduce identical RNG consumption across platforms.

The shared JSON budget covers two full rounds, three tournament matches and
three bounded final attempts, plus setup. Peer deadlines are 240/1140 seconds;
the Node supervisor adds 60 seconds. CI has an 85-minute Lab job budget for
all six ordinary/tournament peer groups and setup. The original failing seed
is added alongside, not instead of, random groups and the existing seeded
tournament regression.

## Executed evidence

- Six Godot configuration/budget assertions passed, exit 0.
  `/tmp/kras-lab-natural-budget.log`.
- Node budget test passed, including authored-duration parity and the complete
  CI time envelope. Workflow YAML parsed successfully; diff check passed.
- All 344 scripts compiled; runtime/compile log guards passed.
  `/tmp/kras-lab-natural-compile.log`.
- Final local server suite: 185 tests, 179 passed, six capture-dependent tests
  skipped, zero failures, exit 0. `/tmp/kras-lab-natural-server-final.log`.
  The earlier sandboxed server run failed `listen EPERM`; rerunning rooms and
  budget tests with loopback permission passed all 59. The skipped capture
  tests are not counted as completed in the local suite.

Actual four-engine, real WebSocket, authored-duration match:

```sh
GODOT_BIN=/opt/homebrew/bin/godot caffeinate -i node network-smoke.js \
  --game=lab_crates --humans=4 --seed=1302046270
```

Exit 0, all four peers passed unchanged strict Lab weapon/projectile observation,
movement, world validation and result consistency checks. Scores were
`[87, 40, 32, 60]`; host and peer 2 reconnected. Guests observed 4108/4089/4108
world snapshots. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-yE8CQZ`.
These are scripted human input sources, not four people using the graphical UI.
Server maximum delay was 3618 ms on this shared Mac, not a performance pass.

An earlier natural-duration attempt failed before any match started:
`kras-network-smoke-gO7E0L` under the same temporary parent. It remained in the
lobby and expired reconnect after large scheduling gaps (server maximum 94154
ms). It is not counted as completed gameplay. `caffeinate -i` was scoped to
the successful retry process only; the cause of the earlier gaps was not proved.

## Independently verified preceding full core

GitHub run 37230877167's completed core artifact records intended head `0a60b58`,
checkout `2fa917bcb882f84e4dfb61514267f2fc02e991b4` and tree
`5da0711302513362c02629f28569646a3c7ece6c`, with no tracked changes.
That tree exactly matches the local `0a60b58` tree.

- Full core: 30,949 assertions passed in 285.2 seconds.
- Stability: 117 short matches, zero failures; not a natural full-round balance
  campaign across all maps.
- Server tests with actual Godot captures: all 184 passed, none skipped.

Artifact: `/tmp/kras-current-core-evidence-37230877167/`.
The whole workflow was still running with 33 successful jobs and a failed
`network-fawda` job when inspected. Its successful core is not an all-network
qualification. These are preceding-source results; final-source CI remains
required after committing this testing change.

## CI operations and remaining work

Superseded owned campaigns were cancelled only after verifying their commits
were ancestors of the final source and a final-source campaign existed.
Runs 37221869762, 37222295173, 37223420263, 37224033231, 37225390256 and
37228923704 are cancelled, not successful. Run 37221393707 became terminal
before its cancellation request, which was rejected. Existing failure logs
and artifacts remain available; Fawda still requires investigation.

This is not a full tournament run of the new natural-duration fixture, a
Linux final-source pass, physical iPhone performance/thermal/battery QA,
production rollout or signed App Store submission. Those release gates remain
open. No main merge, production multiplayer enablement or Apple upload occurred.
