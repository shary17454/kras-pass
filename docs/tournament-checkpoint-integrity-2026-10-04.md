# Tournament optional-field integrity

This follow-up extends PR #52's checkpoint validation, without changing the
save version or writing/deleting user data. It validates seed, boolean flags,
metadata strings, reward identity format, optional performance/trailing arrays
and their values, and roster field types before PlayerConfig conversion.

Absent legacy optional fields still use their previous defaults. Empty legacy
performance arrays remain supported. Integral JSON floats remain supported.
Native integer seeds retain their full range; floating seeds must be finite,
integral and exactly representable within the JSON safe-integer range.
Zero retains the existing normalization to seed 1. Name/profile/palette values
are not converted from arbitrary objects or numbers.

## Evidence

- Before fix: focused integrity suite returned 13 passed and 14 failed, with
  SCRIPT ERRORs from bool/String constructors on malformed metadata and roster
  values (`/tmp/kras-checkpoint-integrity-before.log`). Some null-return
  assertions passed due to script errors: the run is not partial qualification.
- Final expanded focused suite: 55 assertions passed in 0.1 seconds, including
  JSON seed preservation, valid current/legacy saves, malformed optional fields,
  invalid rewards/participants and source dictionary immutability
  (`/tmp/kras-checkpoint-integrity-json-final.log`).
- Existing party regression suite: 4171 assertions passed in 86.1 seconds
  (`/tmp/kras-checkpoint-party-regression.log`). This includes valid cup/points
  checkpoints, version-1 restoration, tournament completion and local controls.
- Compile: 336 scripts passed (`/tmp/kras-checkpoint-integrity-compile.log`).
- All runs used separate temporary test save directories, not the real profile.

The focused suite is registered in tests/test_runner.gd and therefore included
in the full existing CI suite. No test gates or process deadlines are relaxed.
Godot log guards and diff checks are required before publishing this follow-up.

## Remaining scope

This does not establish semantic validity of every custom match rule, migrate
every published device save, or qualify the complete player save system.
Readiness on iPhone, full Linux minigame/network/balance matrices, production
Railway integration, Distribution Archive and Apple submission remain separate
requirements. No schema bump, main merge, deployment or upload is performed.
