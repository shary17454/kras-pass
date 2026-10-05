# Replay index interruption recovery

## Product correction

A replay's atomic file commit precedes its profile-index update. Previously,
interruption between those operations left a complete recording permanently
absent from the library. Store startup now schedules a bounded recovery pass.

Recovery ignores indexed files, directories, symlinks, temporary suffixes,
unsafe IDs, empty/oversized files, invalid JSON/schema/payloads, filename/content
identity mismatches, empty captures and unavailable games. Invalid or temporary
data is retained, not promoted or destructively removed. Valid complete files
reuse the same metadata builder as ordinary saving. Retention limits still apply.

The pass reads at most 256 MiB and stages at most 40 new recordings, yielding
between payload reads. It stages metadata locally, rechecks the storage root,
profile writability and deletion generation, merges with the current index,
checks files still exist with the observed size, then commits and notifies UI.
An erase or erase-all request cancels an in-flight pass. A newer profile schema
arriving while the coroutine is yielding also prevents publication or writes.
Ordinary explicit replay loading retains its existing unreadable-file error;
recovery quietly skips invalid JSON candidates.

## Verified source and checks

Runtime source: `c2729cbcad35187b41bbc19e7ed5b0a5db15e6f1`, parent
`6af4caf7e23288e0722ee42327724180cc1f87e9`. Targeted recovery and compile checks
ran identical runtime files before commit; regression suites were rerun on the
committed source. No runtime files changed during these executions.

| Check | Assertions | Log |
| --- | --- | --- |
| Interrupted index recovery and startup | 27 | `/tmp/kras-replay-recovery-qualified.log` |
| Atomic storage and budgets | 33 | `/tmp/kras-recovery-storage-final.log` |
| Newer-save protection | 64 | `/tmp/kras-recovery-future-save-final.log` |
| Actual capture/playback and legacy migration | 71 | `/tmp/kras-recovery-integration-final.log` |

All returned exit 0: 195 assertions. Compile check: 364 scripts, exit 0,
`/tmp/kras-recovery-compile-final.log`. `git diff --check` passed. Successful
logs were explicitly scanned for script/native ERROR, crash and leak markers;
none found. Deliberate invalid-file and future-save fixtures may emit warnings.

Tests create an actual committed replay file without an index entry, recover
and reload it, confirm exact byte metadata, refuse mismatched/partial files,
exercise zero read budget and idempotence, create a fresh store node to prove
automatic startup recovery, delete a candidate during the coroutine yield,
and install a newer profile during that yield to reject staged metadata.
This simulates the on-disk interruption state and real initialization path;
it is not an actual OS process-kill/power-loss experiment.

## Limits and remaining work

- Yielding between files does not move JSON parsing off the main thread. A
  single large replay may still cause a frame-time spike; device measurement
  and threaded parsing remain unqualified.
- Deferred candidates beyond the bounded pass are reported but no persisted
  resume cursor is implemented. Repeated invalid large files could consume
  the next pass's read budget again. Large orphan libraries need follow-up
  work before claiming complete recovery in every case.
- Temporary files are intentionally not promoted. Disk-full/fsync/power-loss,
  directory enumeration scale, symlink fixtures, live replacement with identical
  file size, and cross-profile switching still need explicit qualification.
- Retention may delete old valid indexed recordings according to the existing
  bounded-library policy; preserving malformed candidates does not count them
  as playable recovered content.
- Full CI, all39 replay fidelity, physical iPhone/iPad performance/thermal QA,
  source integration, Railway synchronization and Apple archive/upload/review
  remain release gates. No main merge or Apple submission occurred here.
