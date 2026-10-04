# Fawda pickup arbitration and remaining network gate

## Source

Branch `fix/kras-fawda-pickup-arbitration` builds on Tank repair
`38dfeed7db512f18b4482fb7275fa4a6f1fa7cde`. Runtime pickup arbitration
was saved in `ef1f945de07b183f64cf18fa4408878dd534124f`; the authoritative
elimination fixture in `0c073795f9090d45957f18ad2c8d5561fcea0f37`.
Read-only network diagnostics belong to
`854f315da07f2cdc1b51fc4297dfc8c7e33daccf`.
The user-requested `git add .` commit also saved generated test script UIDs.
No merge into main, Railway deployment, Apple archive or review submission.

## Repair and focused tests

The old pickup loop awarded the first eligible slot, even when another
eligible player was closer. Exact ties also always favored slot zero.
Pickup now chooses the nearest eligible player; exact ties sort by player
slot then use the gameplay RNG. Unique nearest pickups consume no tie RNG.
Range, fast-bomb rejection, carrying checks, fuse and authority are unchanged.

Regression before the runtime fix: 163 passed, five failed in
`/tmp/kras-fawda-arbitration-before.log`. Tests cover nearest arbitration,
256 seeded ties, seed reproducibility and reversed candidate order. Reversing
the fixture array is not a claim that gameplay permits arbitrary roster
ordering; MatchContext normally requires array index to equal player slot.

A later fixture initially failed because it changed Fighter.alive without
the authoritative MatchContext.alive entry. It now uses eliminate/revive and
the real body respawn path, and retains dead-player rejection assertions.

- Final Fawda suite: 171 assertions passed, exit zero,
  `/tmp/kras-fawda-arbitration-authoritative.log`.
- Compilation including the diagnostic peer: 335 scripts passed, exit zero,
  `/tmp/kras-fawda-probe-compile.log`.
- Log guards and whitespace validation passed. The headless macOS system-CA
  warning is an environment baseline, not Internet connectivity proof.

## Network failure retained, not hidden

Two real Godot processes and the loopback WebSocket service attempted a
three-match tournament with two scripted human input sources and two Bots,
seed `1846961932`. No teleport, score injection or relaxed event gate was used.

At `0c07379`, the first storm_ring match failed required pickup evidence on
both peers. Scores matched `[2,4,8,8]`, but that is not a passed tournament.
Evidence: `kras-network-smoke-EeTlL5` under the session macOS temporary directory.
Server event-loop maximum was 3727 ms; host frame gap was 17800 ms.

The diagnostic repeat at `854f315` also failed the first storm_ring match.
Both peers observed drop/explode but no pickup/throw. Scores matched `[2,5,8,8]`.
Host diagnostics: 2493 observations, 1901 slow-loose bomb observations,
zero eligible in-range pairs; minimum observed eligible distance 2.736527 m.
Guest minimum was 2.789937 m and zero in-range pairs. The closest host sample
was slot three, bomb four, first internal round, fuse 4.766667 seconds.
Evidence: `kras-network-smoke-vqsbwD`; server maximum 2852 ms, host gap 14499 ms.

These sampled distances narrow investigation toward movement/match conditions.
They do not prove a root cause, cover every rule-tick ordering, or certify
smooth gameplay. Diagnostics are bounded scalar/closest-sample state in the
test peer only; they do not change player inputs or game rules.

The older Linux failure also affected both peers: run `37174083976`, artifact
`11294476418`, checkout `c834d5be513738d3b2cee67be39b61dd231b9446` (PR merge,
not the intended branch head). Local downloaded evidence is under
`/tmp/kras-pr42-fawda-evidence`. It is not resolved by this fairness repair.

## Release gates

Further natural pickup/throw qualification, movement diagnosis, full current
source tests/balance, physical iPhone/gamepad/Internet sessions, thermal/battery
measurements and remaining product requirements are still required.
The existing iOS QA export is from 9ef106f, not this source. Production health
currently reports ok/authentication ready, but multiplayer remains disabled.
Do not deploy or send this unqualified source to Apple review.
