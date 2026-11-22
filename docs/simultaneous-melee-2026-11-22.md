# Simultaneous Melee and Replay Compatibility

Base: `1c58314a8bc3783fd9a088ceb80f64a317d8a7db`.
Implementation branch: `fix/simultaneous-melee-20261122`.

## Reproduced Defect

Two eligible attack edges in one simulation tick were processed sequentially.
The first accepted hit applied hitstop/stun before the other fighter read its
input. Reversing only the execution array reversed the only successful swing.
The clean RED run passed 552 assertions and failed 24, without engine errors.
An earlier fixture-type-error run is retained but is not accepted RED evidence.

## Repair

- New matches prepare all fighter commands, resolve prepared melee, then integrate movement.
- Jump/dash/attack ordering, authored tuning, and body-contact equations remain unchanged.
- Existing protection and one-hit immunity remain effective. Multiple contenders are ordered by distance, then stable slots for exact ties.
- Standalone `Fighter.tick()` retains the previous ordered semantics for legacy playback.
- Replay container version 6 records an independent `combat_revision`. Older files without it select revision 0; new recordings select revision 1. Re-saving a historical recording preserves its combat revision. Unsupported revisions are rejected rather than guessed.
- New-format recordings are rejected by older readers instead of silently replaying different combat rules.

## Verification

Godot 4.7.1 official, local macOS, isolated save roots:

- Compilation: 481 scripts, exit 0.
- Focused melee/replay/schema compatibility and Siege network suites: 1,707 passing assertions.
- Full suite: 524,132 passing assertions, exit 0, 498.7 seconds; 1,068 pinned files unchanged during execution and matched again before commit.
- Server: 427 tests passing, none failed/cancelled/skipped, using six fresh Godot world-schema captures. Captures and tested source remained unchanged during the server tests.
- The full test guard passes. Its four deliberate Save/Router fault-injection ERROR messages and two inner negative-harness assertions are retained; the strict runtime-only guard rejects that log as expected. Do not describe the full log as error-free.
- Replay storage tests use a unique child root, restore the enclosing storage/index state, and exercise a real historical v5 disk file through migration and re-save.

Operational evidence is retained outside Git under
`qualification-quickplay-20261122/melee-order-regression/` in the parent workspace.
Tested-source snapshots, raw logs, terminal statuses, rejected attempts, and parent review are separate artifacts; this document is not a replacement for them.

## Open Gates

This proves the reproduced melee-order repair, not complete character balance.
Base Siege's game-specific destructive callbacks still retain an older ordered
interaction; that is a separate known issue, not a newly introduced regression.
Changed-source balance/catalogue QA, physical-device performance/touch/audio,
Duo gameplay, and a fresh signed Store archive/upload/submission remain open.
The old Store build 113 and the separately installed AdHoc source do not contain
this repair. No App Store readiness or submission is claimed here.
