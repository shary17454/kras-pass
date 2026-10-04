# Fawda natural endings and network evidence

## Diagnosis from reproduced failures

No gameplay or production network protocol changes are made here.

The inherited peer smoke required drop, pickup, throw and explode in every
match, including short survival rounds. Actual evidence contradicts that
assumption:

- Restored final, seed `1993721724`, `storm_ring`, contenders `[0, 2]`:
  the actual round ended with slot 2 alive after 3.7833333333 simulated
  seconds. Its only bomb still had 3.2166666667 seconds on the fuse.
  Result `[6, 2, 8, 4]` matches the old CI failure exactly.
- Four-human first tournament round, seed `1528023384`, `storm_ring`:
  actual host ended with slot 3 alive after 5.15 simulated seconds,
  bomb fuse 1.85 seconds, events drop/pickup/throw but no explode.
  Result `[2, 5, 7, 8]` also matches the old CI failure exactly.

Both missing-event failures were reproduced on the host, so neither proves
lost guest explosion delivery. Winner detection legitimately stops gameplay
before the remaining fuse expires. Do not prolong the game, inject bombs or
make players invulnerable just to satisfy the old test.

## Corrected verification scope

- Every host round must end through natural survival or clock expiration.
- Final survivors must belong to the actual contender list; spectators
  cannot remain alive. Draws at real timeout remain supported.
- Every completed match records the actual host/guest terminal bomb world
  and observed-event history. All peers must agree on each match, not just
  scores. Missing bombs, different fuses/carriers or lost events fail.
- Normal campaigns still require real drop, pickup, throw AND explode
  observations on every peer, accumulated across the campaign's matches.
  An early winner is valid; a campaign without actual explosion coverage
  still fails. The isolated restored-final fixture is explicitly not a
  complete weapon-coverage campaign.
- Integer identities/counters remain exact. Noninteger numeric differences
  are limited to `1e-12` for JSON decimal round trips. A reproduced difference
  of `4e-18` in a throw position is not a different physics outcome. Tests
  reject a changed position of `1e-8`, altered fuse, carrier and event count.

## Reproduction fixture

`server/fawda-final-checkpoint.js` restores only the preceding standings by
calling the real Tournament `next`/`record` APIs on host results captured
in CI run 37230877167:

`[8,2,9,4]`, `[9,2,8,8]`, `[8,8,8,8]`.

These yield points `[11,5,11,8]`, contenders `[0,2]`, epoch 4 and the recorded
`storm_ring` final. The following final is real Godot physics, bots, input,
WebSocket transport and authoritative results. The preceding three matches
are restored records, NOT three new live gameplay matches.

Command: `GODOT_BIN=/opt/homebrew/bin/godot caffeinate -i node network-smoke.js
--game=fawda --humans=2 --tournament --fawda-final-checkpoint`.

The option is smoke-only, requires exactly two humans and tournament Fawda,
and cannot be combined with an unrelated seed. Production has no such option.

## Executed results and preserved failures

- Initial restored final failed the old pickup requirement, exit 1:
  `/tmp/kras-fawda-final-checkpoint-reproduction.log`, peer directory
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-JC1trQ/`.
- Four-human strict per-match run failed the old explosion requirement,
  exit 1: `/tmp/kras-fawda-world-parity-tournament.log`, peer directory
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-2GiT5g/`.
- Corrected four-human campaign completed three live matches on all four
  Godot peers with every bomb event observed, reconnects and matching
  standings. Parent initially exited 1 on exact double comparison ONLY:
  `/tmp/kras-fawda-early-round-campaign-recheck.log` and peer directory
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-X2VVZl/`.
  All peer stdout files contain `NETWORK_FINISHED` without peer failures.
  Their actual captures were revalidated with the final comparator:
  `CAPTURE_REVALIDATED`, 4 peers, 3 matches, all four events on each peer,
  scores `[5,9,8,2]`. This revalidation does NOT retroactively change the
  original parent exit code or constitute a new gameplay run.
- Final-source isolated restored final: exit 0, two real peers, score
  `[6,2,8,4]`, champion `[2]`, unchanged preceding points, same bomb/fuse/
  event state, host and guest reconnects, 349 guest world snapshots:
  `/tmp/kras-fawda-final-complete-recheck.log`, peer directory
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-4xtOwg/`.
- Godot ending-policy suite: 14 assertions passed, clean log guard:
  `/tmp/kras-fawda-end-evidence.log`.
- Node evidence/restoration suite: 7 tests passed, including negative cases.
- Final server suite: 192 tests, 186 passed, 6 actual-capture-dependent
  skips, zero failures: `/tmp/kras-fawda-network-evidence-server-final.log`.
- All 347 scripts compiled, clean log guard:
  `/tmp/kras-fawda-campaign-compile.log`.
- Workflow YAML parse and diff whitespace checks passed.

CI now runs the isolated recorded final and the preserved four-human
tournament seed before the existing random groups. The 55-minute Fawda
budget covers 3 ordinary groups at 180 seconds, 5 tournament/checkpoint
groups at 360 seconds and 600 seconds setup. No live process was cancelled
just because observation timed out.

## Remaining release qualification

Linux CI on this final commit is still required, including ordinary,
tournament and event-coverage cases. These scripted Mac runs do not prove
physical-device touch/controller usability, 60 FPS, battery or temperature.
Final restored run had a server event-loop maximum of 3230 ms; it is not a
performance pass. No main merge, Railway production change, Distribution
archive, App Store upload or review submission is claimed.
