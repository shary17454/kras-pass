# Sovereign world adapter qualification (2026-10-03)

Starting source: `b4dedef70a751dbea262d2a8ba7b8d00bbed621b` on
`feature/kras-online-release`. This is an adapter checkpoint, not a completed
online game or an App Store release.

## Implemented

- `sovereign_replica.gd` captures the host boss health/phase/pose, damage/strike
  sequences, shield visibility, recovery window, warning circles and outbound
  or returned orb positions. Orb velocities, future attacks and score authority
  are not copied into guest simulation.
- Both validators enforce exact field counts, phase/health/defeat agreement,
  a shield only in phase two, finite recovery in `[0,2.8]`, bounded vectors,
  unique canonical IDs, at most 64 warnings and 32 orbs, and boolean return
  state. The existing boss/warning validators are reused.
- MatchReplica captures, validates and renders the world. Views have no
  collision objects or authoritative callbacks. Removed views are freed;
  replacing a replica retires its previous view. Next-round snapshots restore
  the boss and hide the previous shield.
- Presentation-only guards cover pursuit, siege, shield creation, orb creation
  and simulation, collapse, core strikes, phase callbacks and round resets.
  Inherited boss damage/strike/tick guards remain in force.
- Warning rendering is shared by Forge, Dreadnought and Sovereign. A changed
  radius replaces the old geometry; absent warnings are pruned. The tests
  verify replacement and freeing, not just dictionary sizes.
- Existing authored boss health, damage, phase thresholds and attack periods
  are unchanged. No room allowlist, production endpoint or availability flag
  is activated by this adapter.
- CI requires a fifth fresh actual Godot world capture before its server
  schema tests. YAML and all six embedded shell blocks parsed successfully;
  parsing is not execution on Linux.

## Feedback timing regression

The initial shared-renderer reruns failed one existing audio assertion each:
Forge 137 passed / 1 failed, Dreadnought 113 passed / 1 failed. Read-only timing
diagnostics then measured sample gaps of 1,204 and 1,028 ms. Those samples
were outside the existing 1,000 ms fresh-event window, so suppressing the
historical sound was the intended runtime behavior. The test fixtures had
called the samples fresh without controlling the wall-clock gap through
scene construction and an awaited frame.

`MatchReplica.receive_clock` defaults to the same `Time.get_ticks_msec`
callable in production; it is not a field accepted from network packets.
The three focused fixtures now supply a monotonic test clock, verify sound
at exactly 1,000 ms, and verify state updates without historical audio at
1,001 ms. The runtime window was not widened or removed. Duplicate samples
and reconnect/new-round baselines are still quiet.

Diagnostic evidence:
`/tmp/kras-sovereign-forge-gap.stdout` and
`/tmp/kras-sovereign-dread-gap.stdout`. Both remain failed runs, not passes.
Corrected focused Forge: 141 passed; Dreadnought: 117 passed.
Sovereign initially passed 109 assertions, then 112 after the clock-boundary
tests; the subsequent full gate also includes warning-radius replacement.

Node's two focused Sovereign tests passed with zero skipped, using the real
`sovereign-world.json` written by Godot. The capture has actual core damage
(1,440 health / one damage event), four controller-created orbs and one
warning. These are controlled host/guest scene fixtures, not a full online
fight or a character-balance simulation.

## Current full-gate evidence

The local full gate uses Godot 4.7.1 and the uncommitted adapter changes on
the starting commit recorded above. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.CVtse5`.

- Compile: 313 scripts passed.
- Inventory: 351 resources, 21 autoloads, 27 routes, eight characters, zero
  reported issues.
- Unit/integration runner: 20,756 assertions passed, including the warning
  radius replacement/freeing checks and controlled audio clock boundaries.
- Actual three-lap race: all four racers completed.
- Actual authored boss fights: Colossus seeds 345, 9614 and 172, and Forge,
  Dreadnought and Sovereign seed 9614 defeated their bosses. Forge still has
  one zero-scoring Bot; these wins do not certify character balance.
- Stability sweep: completed 39 matches with zero failures. It verifies
  completion, cleanup, released input sources and return to node/orphan/signal
  baselines. Timed rounds are shortened; race laps are unchanged. This is one
  cycle and does not establish long-session memory stability or device FPS.
- Server: 113 tests passed, zero failed or skipped, using all five actual
  Godot world captures from this same evidence directory. Log:
  `/tmp/kras-sovereign-network-server-full.log`.

The only observed error-log entry is the intentional save-write failure
fixture (`test_save.gd:_failed_write`). It verifies that a failed write stays
dirty and can be retried; it is not a release/runtime save failure.
`git diff --check` passed. The ongoing GitHub run 37069444943 tests
`5d89d19450c775d24e849496605b82760c406c5c`, not these adapter changes.
The full `tools/check_party.sh` process exited zero; its combined log is
`/tmp/kras-sovereign-network-gate.log`. Compilation, inventory, assertions,
authored race/boss regressions and the stability sweep all completed.

## Remaining acceptance

- Sovereign room contracts and actual separate-process mixed-human/Bot and
  four-client fights, tournaments, finals and resume.
- A qualified Colossus world adapter and its room/network tests.
- Completion of current-source Linux CI, Internet and physical-device QA,
  AI perception/balance, performance, thermal and battery measurements.
- Verified Railway source synchronization and all signed Apple release gates.

The development allowlist remains 37 games. These tests do not establish
four physical players, a healthy deployed multiplayer endpoint, a signed
archive, upload processing or an Apple review submission.
