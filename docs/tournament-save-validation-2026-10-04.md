# Tournament checkpoint validation

## Scope and compatibility

Branch `fix/kras-tournament-save-validation`, based on crate input PR #51.
Validate existing tournament checkpoint fields before conversion: schema
version, schedule index, points, cups, scoring mode, cup target, contender
slots and tiebreak attempts must be finite integral numbers in their existing
bounds. Game, arena and mutator list entries must be strings before typed
array assignment. JSON-decoded integral floats remain valid.

No save schema version changes, file rewrites or progress resets. Existing
version-1 checkpoints retain their points-mode migration; version-2 cup and
points saves retain JSON round-trip support. Invalid checkpoints return null,
but their on-disk contents are not deleted by this change.
This is not exhaustive validation of every optional checkpoint field or of
the complete player save system.

## Reproduced defect and checks

Before runtime fix, `--suite=party` with nine new corruption assertions:
4117 passed, nine failed in 79.6 seconds. Boolean, fractional and numeric
string values were accepted as version, points or cups.
Log: `/tmp/kras-tournament-schema-before-correct.log`.
An earlier invocation with the wrong suite filter selected zero suites and
is not reproduction evidence.

After runtime fix, the same suite passed 4126 assertions in 62.7 seconds
(`/tmp/kras-tournament-schema-after.log`). Expanded malformed-input cases
then passed 4171 assertions in 60.4 seconds
(`/tmp/kras-tournament-schema-expanded.log`). These numbers are separate
runs, not additive coverage totals.

Expanded cases include null, infinity, NaN, dictionaries, invalid contenders,
nonstring list entries and malformed scalar fields. The existing tests also
exercise valid legacy saves, valid cup saves, exact next-game/seed/rules
restoration, local multiplayer controls and tournament completion.

Compile: all 335 scripts passed (`/tmp/kras-tournament-schema-compile.log`).
The tests used separate temporary save directories, not the real profile.
`git diff --check` passed. Godot log guards are run before publishing this
branch. Known headless system CA warnings are not product save failures.

## Release limits

This does not qualify migrations from every published iOS save on a physical
device, the complete Linux matrix, gameplay balance, production networking,
Railway deployment, Distribution signing or App Review submission. Those
remain independent gates for the original full product request.
