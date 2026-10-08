# Test save isolation

## Defect and correction

Bare headless test launches previously used the player's ordinary save root.
Backing up the profile/settings dictionaries after autoload startup did not
protect replay files: replay recovery/pruning could run before the harness, and
later test cleanup could remove files while restoring only index metadata.
That also made replay assertions depend on the developer's existing library.

SaveSystem now selects storage before reading either slot. Editor-binary
launches whose entry is under `res://tests/` receive a unique
`user://test-runs/<pid>-<microsecond-tick>` folder when no valid explicit
scratch directory is provided. Absolute explicit scratch paths remain
compatible. Overrides resolving to the player's actual save root are rejected.
Relative invalid overrides do not make a test run use real saves.

Normal editor gameplay retains `user://`. Exported gameplay ignores test-only
arguments and retains `user://`. No save schema, migration, player progress,
unlock or replay-format change was introduced. Private test folders are kept
for failure investigation; no automatic deletion of user files is performed.

The harness prints its selected storage root and retains fixture restoration
for suites sharing an explicit scratch root. Comments no longer claim that
backing up dictionaries protects a real replay library.

## Evidence

- Regression first failed against the old implementation (missing launch-root
  selection), then passed 15 assertions with the correction.
- Bare launch without `--test-data-dir` passed 15 assertions and selected
  `user://test-runs/77759-606117`.
- Bare replay-storage suite passed 33 assertions. It wrote/pruned only its
  automatically isolated replay directory.
- All 425 scripts compile and the strict compile/log guard passes.
- Sorted SHA-256 inventories of 332 existing player files matched before and
  after both bare launches. Generated test-run folders and engine logs were
  excluded; no player file contents or file inventories are published here.
- Full automatic-root current-source run ended after 292.0 seconds with
  392334 passing and six failing assertions. It logged a real profile write
  failure during tank match completion, outside intentional failure fixtures.
  Error-count assertions then failed for tank, ring, fawda, goal, magnet and
  scrap matches. Low free storage was observed during the run, but it has not
  been proven to explain every error count. This run is not passing qualification.
- A focused rerun of the entire matches suite in a fresh explicit scratch root,
  with verbose logging, passed all 6960 assertions and its strict log guard.
  This narrows the failure investigation but does not override the failed full
  run or prove the full source gate passed.
- After the full run, sorted fingerprints of all 332 existing player files
  still matched the initial inventory. Its automatic root was
  `user://test-runs/78626-1660374`.

The workflow now has a `core_only` dispatch option. It executes the same full
core regression, all-game stability, actual-capture server checks and four-peer
mixed tournament; it does not skip assertions within those checks. The default
full networking matrix is unchanged, verified by parsing both configurations.
Core-only runs use a separate concurrency group so dispatch does not cancel
an in-progress full networking campaign. Its forthcoming Linux result must be
checked against the exact pushed commit, not inferred from dispatch success.

The initial inventory comparison differed only in enumeration order; sorting
both inventories produced exact equality. This is recorded rather than
misreported as a changed player save.

Read-only production health still reports authentication ready and multiplayer
disabled. No Railway mutation, main merge, archive, upload or App Review
submission was performed for this correction.

Evidence: `docs/qa/test-save-isolation-2026-10-08/`.
