# Replay Binary Payload Integrity

Implementation: `79efa85dcdbdb694834c12920ace747402b76e91`.
Parent: `9eda286655b7105ede7a3c50ebcd74307a8aa7a2`.

## Defect and Fix

The reader silently truncated packets or ignored extra complete input frames
when tick_count did not match. Partial correction packets were discarded and
duplicate correction ticks replaced prior state. These cases could present
an incomplete or different recording as the original match.

Check base64 alphabet, shape and canonical encoding before packet unpacking.
For supported v4/v5 packet layouts, require exact input stride/count and
correction channel length and unique normalized correction ticks. Reject
invalid channels with a warning/null, without changing or deleting the file.
Empty optional correction channels remain valid. Missing legacy tick_count
is still inferred; obsolete pre-v4 layouts retain their existing migration
to an honestly empty input/correction track instead of invented gameplay.

## Final Local Evidence

Godot 4.7.1, headless macOS, isolated synthetic saves:

| Check | Result | Log |
| --- | --- | --- |
| Original truncation regression | 7 passed, 5 failed | `/tmp/kras-replay-payload-red.log` |
| Final binary-channel regression | 29 assertions passed | `/tmp/kras-replay-payload-empty-final.log` |
| Existing schema and corrupt disk-reader regression | 75 assertions passed | `/tmp/kras-replay-payload-schema-final.log` |
| Actual recording/save/playback integration | 71 assertions passed | `/tmp/kras-replay-payload-integration-final.log` |
| Compilation | 355 scripts passed | `/tmp/kras-replay-payload-compile-final.log` |

All final processes exited zero and passed the completed-summary/runtime/leak
guards. An additional explicit search found no native `ERROR:` or
`SCRIPT ERROR:` lines in the final four logs. Expected malformed-file,
future-version and capture-budget warnings are retained.

An intermediate implementation called raw_to_base64 on empty arrays, producing
native errors even though its assertions passed. Logs
`/tmp/kras-replay-payload-final.log`, `/tmp/kras-replay-payload-schema.log` and
`/tmp/kras-replay-payload-integration.log` are not clean successful evidence.
Empty channels now bypass that call; all affected suites were rerun. The
shared log guard does not reject every generic native ERROR at runtime, so
the additional explicit native-error check was necessary, not suppressed.

## Limits and Remaining Work

This does not establish all-world event fidelity, all-game natural-duration
playback, file-size/retention limits or crash-safe atomic replay writes.
The existing four-minute capture budget remains; extending recordings needs
bounded storage, not just deleting the safety limit. No format/version bump,
physics, multiplayer protocol, Railway deployment or Apple submission.
CI and physical-device qualification remain separate gates.
