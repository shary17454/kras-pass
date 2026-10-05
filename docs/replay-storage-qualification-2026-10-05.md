# Replay Storage Qualification

Implementation: `5f158ab20e4a3c3cf79172a0669ea179919d2fc7`.
Parent: `d6d09c20ec5ffc67e68deae19e5a550c702d57bb`.

## Change

Save to a sibling temporary file, flush and check the write status, then
rename over the destination. Update the library index only after a successful
file commit. Failure leaves the previous destination untouched; a failed
rename removes the staged file. No remove-before-rename fallback.

Reject replay reads exceeding 64 MiB before loading their text into memory.
Reject writes exceeding that UTF8 byte budget. Keep the indexed library
within 256 MiB as well as its existing 40-recording bound, retaining the
existing preference for highlights over older unhighlighted recordings.
Measure actual JSON file bytes instead of raw-input estimates; refresh stale
size metadata from disk during index loading and before pruning. This is a
storage policy, not an unlimited long-recording feature or a memory benchmark.

## Local Evidence

Godot 4.7.1, headless macOS, isolated synthetic save paths:

| Check | Result | Log |
| --- | --- | --- |
| Final storage/failure/budget checks | 33 assertions passed | `/tmp/kras-replay-storage-types-final.log` |
| Actual recording/save/playback integration | 71 assertions passed | `/tmp/kras-replay-storage-integration-final.log` |
| Compilation | 356 scripts passed | `/tmp/kras-replay-storage-compile-final.log` |

All final processes exited zero and passed completed-summary/runtime/leak
guards. Explicit native ERROR/SCRIPT ERROR searches found no matches in the
final logs. Warnings for deliberate write-open/rename refusal, oversized read
refusal, future versions and the existing capture budget are expected.

Tests compare the exact original file after rejected replacements, exercise
a blocked temporary path and an actual rename failure, verify complete retry
replacement and no remaining temporary file, repair invalid size metadata,
and prune according to real bytes while preserving highlight preference.
A sparse 64 MiB + 1 byte file proves rejection before JSON parsing; reader
refusal does not delete it. Synthetic fixtures are then removed. Pruning uses
a small injected internal byte limit to exercise actual disk files cheaply;
this is not a 256 MiB endurance benchmark or a disk-full simulation.

An intermediate stale-size test revealed an invalid Dictionary/int comparison
(`/tmp/kras-replay-storage-final.log`). Its summary printed 32 assertions but
the log guard failed because of SCRIPT ERRORs, so it is not successful
evidence. Type-check the stored size before numeric comparison; the corrected
test and affected integration/compilation were rerun without weakening it.

## Remaining Gates

No power-loss, filesystem durability, iOS rename or disk-full fault-injection
qualification yet. Crash recovery for orphan files/index reconciliation and
read-only/future-save handling still need investigation. The byte budget
covers indexed recordings, not arbitrary orphan or manually placed files.
The four-minute capture limit and all-game replay fidelity are unchanged.
No format, gameplay, network or Railway change. CI, physical-device QA and
the exact-source Distribution archive/App Store submission remain pending.
