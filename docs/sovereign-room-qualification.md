# Sovereign room qualification (2026-10-03)

Starting source: `7e5b34093b1a55a287d0dd58dee55171c7ad6e05`, branch
`feature/kras-online-release`. The previous adapter checkpoint is documented
in `sovereign-network-qualification.md`. Its full-gate results apply to that
commit, not automatically to these later room/event changes.

## Room contracts

The server and client development catalogues now accept `boss_sovereign` on
its authored `vortex_ring` only. The production endpoint and availability
configuration are unchanged. This adds a development candidate, not a claim
that its online qualification is complete.

Room tests verify invalid arena rejection, host-only world/results, malformed
world rejection without overwriting the previous accepted snapshot, guest
identity/world/result restoration and host result restoration after reconnect.
The boss tournament contract also checks that resolving a tied final does
not change ordinary points or cups.

- `/tmp/kras-sovereign-room-server.log`: 56 tests passed, zero skipped.
- `/tmp/kras-sovereign-room-godot-local.log`: 85 assertions passed.
- `/tmp/kras-sovereign-room-compile.log`: all 313 scripts compiled.
- `/tmp/kras-sovereign-room-events-server.log`: 56 tests passed after the
  event schema extension, zero skipped.

The first isolated Node attempt failed `listen EPERM` on localhost; the
local-session rerun above passed. The first isolated Godot attempt failed
to open its `user://logs` file and crashed before loading project tests;
the local-session rerun passed. Those failed attempts are not test passes.

## Real network failure and fix

The first separate-process two-human/two-Bot smoke used seed 9614 and room
`EEP4YU`. Both internal rounds defeated the actual boss, but its required
orb-return evidence failed. Evidence:
`/tmp/kras-sovereign-room-two.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Dh5ctc`.

An orb can be swung back, reach the shield and be removed within the same
physics step. Object rows alone therefore lose launch/return events before
the next network snapshot. This was not repaired by lowering damage,
extending recovery, disabling the assertion or making a client authoritative.

The host now counts volley and return generations, reset each round. The
seven-field world schema bounds both integers and prohibits more returns than
four times the volley count. Guest views use these generations for fresh
one-shot feedback, including when the corresponding object is already gone.
Duplicates, historical snapshots and reconnect baselines remain quiet.
Future attacks, projectile velocities and authority are still not copied.

The regression fixture performs actual swings: one returned orb remains
visible, then four immediate returns disappear before a snapshot. It verifies
the preserved events, valid schema, round reset, bounded input and quiet
replacement baselines.

- `/tmp/kras-sovereign-return-events.log`: 141 assertions passed.
- `/tmp/kras-sovereign-return-schema.log`: two server schema tests passed,
  zero skipped, using the fresh real Godot capture.
- `/tmp/kras-sovereign-room-events-compile.log`: all 313 scripts compiled
  after the event generation fix.
- `/tmp/kras-sovereign-room-full-server-corrected.log`: all 115 server tests
  passed, zero skipped. The four older game captures are from the previous
  full gate; the Sovereign capture is from the fresh 141-assertion fixture.
  The first full server invocation failed only because the supplied race
  capture path was `armed-race-world.json` instead of `armed-world.json`;
  `/tmp/kras-sovereign-room-full-server.log` retains that failed attempt.

## Actual two-client result

The corrected separate-process smoke exited zero: two scripted humans and
two normal Bots, seed 9614, two internal rounds. Both rounds recorded actual
damage, volleys, shield, return generations and boss defeat. Both peers
reconnected, retained distinct identities and agreed on scores
`[1200,660,720,450]`. The guest received 2,790 world snapshots. Evidence:
`/tmp/kras-sovereign-room-two-events.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-W3XChP`.

This is localhost scripted input, not physical players or Internet/mobile
latency certification. The server event-loop maximum was 1,361 ms, and the
host maximum frame gap was 9,992 ms during scene preparation. These are
unresolved performance risks, not acceptable device FPS evidence. The fight
logs also show collapse warnings outside the arena while fighters are falling;
target eligibility and recovery need their own regression/QA pass.

## Pending qualification

Four-client fights, tournaments and forced finals remain required. The automation sends
ordinary movement/attack input based on visible boss, warnings and orb rows;
it does not write boss health or fabricate game results.

Internet/mobile performance, long-session memory/battery/thermal QA,
Colossus replication, CI on the final source, Railway source synchronization
and signed Apple release gates remain outstanding. No production deploy,
Archive, upload or App Review submission was performed in this checkpoint.
