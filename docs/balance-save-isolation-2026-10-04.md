# Balance Save Isolation

## Change

The balance tool disables control hints and replay capture through persistent
settings. It must not run those setters against the normal player save slot.
Startup now requires an explicit absolute external save directory before opening
its progress log or changing settings. It rejects `user://`, `res://`, relative
paths, filesystem roots, the actual player data directory, and its children.
Path simplification prevents a `..` spelling from bypassing this lexical guard.
Failure to open the isolated progress log also stops before settings setters.

This is an accidental-path safety check, not a filesystem sandbox or a full
symlink-resolution security guarantee. Supplied directories must be trusted.
The shared SaveSystem format, migrations, and shipped gameplay are unchanged.

Use:

```sh
godot --headless --fixed-fps 60 --path . tools/balance_sim.tscn -- \
  --runs=8 --test-data-dir=/tmp/kras-balance-save
```

The existing balance campaign workflow already supplies a dedicated runner-temp
save directory. The QA command and tool comment now include the required option.

## Evidence

- Final unit policy suite: 464 assertions passed, including the drive-root case.
  `/tmp/kras-balance-isolation-policy-final.log`.
- Actual tool `_ready()` was exercised with an isolated Autoload startup, then
  an unsafe `user://` root. The probe disabled SaveSystem writes and monitored
  settings-change signals. It exited 2 with the expected isolation error before
  any settings mutation signal. No balance match was run by this refusal test.
  `/tmp/kras-balance-refusal-startup.log` and
  `/tmp/kras-balance-isolation-probe.gd`.
- The same startup probe used an owned existing file as the storage root. The
  log could not be opened beneath it, so startup exited 2 with the expected
  write error before any settings-change signal.
  `/tmp/kras-balance-unwritable-startup.log`.
- The final policy log passed `tools/check_godot_log.sh` in tests mode.
- `git diff --check` passed.
- This is a safeguard following the interrupted non-isolated invocation recorded
  in `bomber-observed-cues-2026-10-04.md`. It does not retroactively qualify that
  invocation or guess the previous local setting values.

## Remaining Gates

No new natural-duration balance result is claimed for this startup-only change.
The previous Fawda sample still has an unresolved Expert/Easy warning. Full
all-game/physical-device/Online qualification, main integration, distribution
archive, upload, processing, and actual App Review submission remain separate.
