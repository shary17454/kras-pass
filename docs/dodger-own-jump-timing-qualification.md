# Dodger own jump timing

Runtime source: `09959fd4bd7d434cb0ad861ac6dc3abe8c3d634e`.
Parent: `c5aeab06155af9bb407d1a6f64f85548987a5e25`.

The dodger used a universal 0.34-second jump lead for every character and
gravity modifier. A player's actual jump velocity and current gravity differ;
using a fixed lead mistimed the apex, especially under low gravity. The brain
now derives the mean lead from its own jump velocity, jump modifier and
effective gravity. These are its own movement capabilities, not private
hazard state. Per-encounter accuracy noise, single timing decision, delayed
visible threat sampling and difficulty parameters remain unchanged.
No roster stats, hazard power, round duration or balance threshold changed.
This is a timing correction, not evidence of complete game balance.

## Regression

The identical final fixture with the original runtime produced 33 passing
and 32 failing assertions. With the correction, all 65 assertions pass.
It covers eight characters, normal/half gravity and normal/boosted jump,
and verifies that one encounter does not reroll its timing every tick.

- `/tmp/kras-dodger-jump-red-local.log`: exit 1, actual assertion failures.
- `/tmp/kras-dodger-jump-green.log`: exit 0, 65 assertions.
- `/tmp/kras-dodger-jump-perception.log`: exit 0, 117 assertions.
- `/tmp/kras-dodger-jump-compile.log`: exit 0, 382 scripts compile.

An initial sandbox engine invocation crashed before testing because it could
not open its user log; the authorized local runs used explicit /tmp logs.
The initial fixture also needed an explicit float annotation before the
documented red/green comparison. Those attempts are not red-test evidence.
Successful focused logs passed `tools/check_godot_log.sh`.

## Natural-round comparisons

Each sample comprises 24 baseline matches, 16 matched seed/character
difficulty matches and two mutator/chaos checks, without shortened rounds.

At offset 600000, parent Expert score share 0.54375 becomes 0.56875.
Average duration changes from 31.0 to 29.034722 seconds. Character bias
remains 0.291667; `character advantage` remains flagged. Wins are fanoos 1,
mowja 5, sakhra 10, turs 8. This does not resolve heavy-character dominance.

At independent offset 900000, parent Expert share 0.559006 becomes 0.56875.
Average duration changes from 23.277083 to 18.083333 seconds; character bias
changes from 0.375 to 0.333333, still flagged. Wins are barq 1, fanoos 2,
mowja 1, ramla 2, sakhra 11, turs 7. Shorter average rounds and remaining
dominance still need design review; neither sample justifies READY status.

- `/tmp/kras-dodger-jump-balance-report/report.json`
- `/tmp/kras-dodger-jump-independent-report/report.json`
- Parent counterparts: `/tmp/kras-sweeper-hitbox-balance-report/report.json`
  and `/tmp/kras-sweeper-hitbox-independent-report/report.json`.

Both new simulations exit 0 and pass the runtime log guard; a zero simulator
exit does not erase its review-level balance flags. The matched run began
before the runtime commit, with precisely the same staged runtime/fixture;
no code changed during it. The independent run used the committed source.

## Networking and release boundary

Four real Godot processes using automated human inputs and a temporary local
WebSocket server agree on `[8, 8, 16, 8]`, move, and resume the host and one
client. Client world snapshot counts are 715, 734 and 734. The test exits 0
and passes the runtime log guard. Maximum observed server-loop interval is
98 ms during concurrent local qualification, not a device frame-time result
or proof of Internet latency. Evidence: `/tmp/kras-dodger-jump-four-peer.log`.

The four-human fixture does not exercise bot decisions. A separate two-human
and two-bot run on the same seed also exits 0 and passes the runtime log guard.
Both peers move and reconnect, agree on `[8, 8, 17, 8]`, and the client receives
737 world snapshots. Maximum server-loop interval is 22 ms. This directly
exercises the host's bot path, not four physical human players or Internet
play. Evidence: `/tmp/kras-dodger-jump-bot-peer.log`.

No iOS device gameplay, full 39-game regression, Distribution Archive,
production-online activation, App Store upload or review submission has been
performed for this runtime change. The existing physical-device authentication
gate and remaining character balance issues still apply.
