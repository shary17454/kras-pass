# Siege final evidence contract

Source: `a43c7176804ab8351a48b2723a46eede10c4b8fd` on
`feature/kras-siege-active-guards`.

Production `Net.make_match_config()` sets contender finals to 20 seconds with
a 25-second safety limit. The server starts tournament matches with one round
and resolves finals using contender scores. A complete crystal destruction is
therefore not a prerequisite for a legitimate short final. Ordinary online
smoke rounds still require real hits and crystal destruction in every round.

The fixture now also accepts final hit evidence plus a positive score for an
actual contender. It rejects spectator-only points, zero scores, missing hits,
invalid contender indices and nonfinite/nonnumeric scores. The existing guest
presentation/collision checks, reconnect checks and final cup/award invariants
remain in place. No production health, damage, duration or scoring was changed.

## Focused tests

`/tmp/kras-siege-final-evidence.log`: 13 assertions passed, exit zero.
The inactive-attacker runtime regression remains separately documented in
`siege-active-guard-verification.md`.

## Two clients plus bots tournament: PASS

Command: `node network-smoke.js --game=base_siege --humans=2 --tournament --seed=9614`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-eVzie2`.

Three real matches completed across `crate_yard` and `iron_flats`. Both peers
reconnected and agreed on final match scores `[15,6,23,0]` and tournament totals
`[9,5,14,6]`, champion slot 2. The guest received 2971 world snapshots. Node
exited zero. All ordinary destruction and guest ownership checks passed.

This run had no tied final (`tie_attempts: 0`) and does not qualify that path.
Server loop delay reached 2636 ms on the shared development host, so it is not
a frame-rate or production-latency certification. The separate four-peer final
result is recorded below; the full fresh release gate remains required.

## Four clients with tied final: PASS

Command: `node network-smoke.js --game=base_siege --humans=4 --tournament --siege-tiebreak --seed=9614`.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-BgmI2b`.

All four actual Godot peers completed three ordinary rounds and one final.
Every peer reported final scores `[4,13,21,9]`, champion slot 2, tournament
points `[3,3,3,3]`, awards `[0,0,0,0]`, unchanged cups `[0,0,3,0]` and one tie
attempt. The host and one guest reconnected. Guests received 2272-2293 world
snapshots and passed crystal baseline/collision ownership checks. Node exited
zero. This final began with all four slots as contenders, so it does not by
itself qualify a spectator client in a contender-only final. Server loop delay
reached 3840 ms; this is functional evidence, not performance certification.

The full fresh release gate, broader minigame network qualification and
physical-device QA remain required before release.

## Full Godot unit/integration suite: PASS

After both real peer runs, the complete `tests/test_runner.tscn` suite ran with
`--fixed-fps 60` and isolated storage at
`/tmp/kras-siege-final-full-suite-save`. It completed in 691.8 seconds, reported
21029 passing assertions and exited zero. Log:
`/tmp/kras-siege-final-full-suite.log`. This includes real three-lap AI route
completion across the authored racing arenas, not forced race finishes.

The compile check passed all 321 scripts, exit zero; log:
`/tmp/kras-siege-final-compile.log`. Neither log matched the release script's
script/parse failure, leaked resource, ObjectDB or RID allocation patterns.
Expected save-corruption and unsupported-input warnings from negative tests
are not suppressed or claimed absent.

These are two components of `tools/check_party.sh`, not a claim that its whole
gate passed: the inventory, dedicated race/boss regression runs and repeated
all-game stability cycles still need fresh qualification on this source.
