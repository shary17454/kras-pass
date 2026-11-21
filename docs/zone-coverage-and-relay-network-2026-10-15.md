# Zone capture coverage and relay network - 2026-10-15

Status: test coverage repair, not a gameplay or balance change.
Stage 0 remains QA_PENDING / MERGE_PENDING.
Base commit: `0dfbc97e16904d921d4231b99789f9af56a4701d`.
Branch: feature/kras-online-random-rotation.

## Real relay probe

```sh
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=crate_relay --humans=4 --seed=510184
```

PASS, exit 0, four independent Godot 4.7.1 processes and a local loopback service.
All peers agreed on `[18,15,12,12]`; all recorded carrying and collection scoring.
Guest world snapshots: 1087-1107. The existing test verifies item presentation,
local carrying and the per-slot cargo marks against authoritative snapshots.
Host ID 1 and guest ID 2 reconnected; eight logs passed the strict runtime guard.
This used the base peer harness before the following zone-specific test changes.

## False-positive zone coverage

The old zone driver aimed at the zone's angle plus a fixed per-slot offset.
Only slot 0 actually approached the capture area. With seed 510185, four peers
returned `[27,0,0,0]`, yet the old probe passed because any player's score set
the observation flag. That proves agreement/host capture, not remote scoring.

A regression for each scheduled participant produced 4682 passes / three
failures, specifically slots 1, 2 and 3. An earlier test edit had a type-inference
parse error and is preserved separately, not used as behavioral evidence.

The retained test-only fix:
- Rotates the active capture participant every six simulated playing seconds.
- Directs that participant to the public zone position; other scripted players
  leave for separate parking angles. It uses normal movement/attack inputs and
  annular routing, not score, position, speed or health writes.
- Uses the public remaining-time/round state, not resource-loading wall time.
- Records each peer's own scoring, clears this observation for every match and
  validates it before the tournament's early next-match return.
- Emits `zone_scored` in synthetic peer evidence.

Focused zone suite: 4731 assertions, exit 0, strict test log guard passed.
It retains existing combat/release/visibility/geometry tests and adds all-seat
steering, untouched body/score checks, one-to-four-player turn boundaries and
derived fixture-duration checks. These are not human control tests.

## Failure retained, fixture budget corrected

The rotating driver's first standalone probe still used the old 15-second
override and two internal rounds. It passed with `[10,5,1,3]`, all peers scoring,
matching guest world state and successful reconnects; eight logs passed.

The first tournament attempt failed, exit 1: every match returned `[4,5,1,0]`
and slot 3 never captured. Tournament matches use one internal round, enforced
by server/rooms.js, so a 15-second fixture could not reach slot 3's 18-24-second
turn. This was a test-budget failure, not proof that production Zone Hold is
broken. Its logs were retained, not relabeled successful.

The fixture now derives a minimum of one complete participant cycle plus one
travel turn: `(player_count + 1) * 6 seconds`, 30s for four players. The ordinary
game definition remains 90 seconds; no production duration, scoring, AI,
arena, seed or difficulty threshold changed. The old intermediate-return bypass
was also removed for the zone-specific guard, so every match must prove capture.

## Final three-match tournament

```sh
GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js --game=zone_hold --humans=4 --seed=510185 --tournament
```

PASS, exit 0. All four peers completed three matches, each with scores
`[10,5,4,4]`. Every seat scored in every match, verified from all four round
histories and by the per-match guard. All peers agreed on the same final state:

- Points: `[15,9,6,6]`.
- Cups: `[3,0,0,0]`.
- Champion: original slot 0; complete=true, round=3, tie_attempts=0.
- Third-place tie awards `[5,3,2,2]` were retained; no fabricated fourth place.

Host ID 1 and guest ID 2 reconnected. Guests received 2568-2587 world snapshots.
All eight final engine/stdout logs passed the strict runtime guard. The one-entry
playlist repeats after exhaustion; this is not mixed-game/no-repeat coverage.
The same seed and deterministic scheduled inputs were reused: three rounds do
not represent three independent balance samples, and scripted turn allocation
deliberately favors coverage over competitive fairness. No sudden death occurred.

## Source and scope

Only tests changed. Runtime source fingerprint remained
`3bb6522645d38973ce59b5d0176a119b0dc7c245d1d8b04afc01c8af503b6014`.
It excludes tests and is not sufficient alone to attest this change. The three
changed test files were separately matched against the tested runtime:

- tests/network_peer.gd: `66f7deecc57c522858c370a0856f4272228c8b7159cb02f677a5b01723661d17`
- tests/zone_peer_driver.gd: `45d1ca841fa35b18c255a058b199b2b0209ab507d21ac76fa7e5481f64ead2c6`
- tests/suites/test_zone_hold.gd: `10ae9d7a0a9c6f900188daf95e28d02ed391eac99778f41dba576b8b7b386b20`

No source/test edits overlapped a live campaign. All 466 scripts compiled and
the strict compile guard passed. No new server-suite run is claimed.

The full Godot suite passed 427798 assertions in 238.7s, exit 0, and its strict
test log guard passed. Four ERROR entries were verified as the intentional
failed-save and router-recovery fixtures, not arbitrary runtime errors.
Full log SHA-256:
`6eeefe0d4d3e7d9668dd3437a53f236264d20dfc3d47a038a72f5921457b9c24`.
No test/source edits overlapped the final tournament or full qualification.

Sibling `qualification-zone-coverage-2026-10-15/` preserves synthetic evidence,
including the rejected short tournament; private save directories were not
copied. Final tournament timing JSON SHA-256:
`809c7a3a2d9a1f37d57f3891fd871981737137a35802c73cf15840cbe64ba6a9`.
Relay timing SHA-256:
`4461acc182d91f373d7c18a280e899f8605ac8713c8dfcffa37e5c0ead74b2da`.

Cumulative host frame gaps were 369ms (relay), 363ms (old zone), 398ms (rotating
short standalone) and 338ms (final tournament), including startup/phase costs.
Console server-loop observations reached 23ms and 32ms in relay/final tournament.
These are not sustained-FPS, physical phone, energy, thermal or Internet proofs.

No production change, Git push/main merge, Railway mutation, fresh iOS Archive,
upload or App Review submission occurred. All-game/device/balance/release gates
remain open; an old all-39 audit is not current readiness certification.
