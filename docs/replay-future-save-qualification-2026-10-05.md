# Replay Future Save Protection

Implementation: `14c657a1b034f5518aa4d97aeac4666141a4b637`.
Parent: `493f1edd3580e0fad88af64b6c2ffe9a96076c16`.

## Defect and Change

Profile writes already protected newer schema files, but replay sidecars could
still be replaced, deleted or pruned while their index was read-only. This
lost recording data despite retaining the newer profile envelope.

Expose SaveSystem.can_write(slot), reusing its existing read-only status and
on-disk main/backup future-schema detection. Replay save, direct atomic write,
erase, erase-all, pruning and index commit all gate mutations. Index loading
uses an independent deep copy and skips cleanup on a protected profile.
Reading a supported recording remains allowed. No schema/version/protocol or
gameplay changes, and no bypass of newer-schema protection.

## Final Local Evidence

Godot 4.7.1, headless macOS, isolated synthetic saves:

| Check | Result | Log |
| --- | --- | --- |
| Before-fix sidecar regression | 31 passed, 33 failed | `/tmp/kras-replay-future-red.log` |
| Future profile/replay protection | 64 assertions passed | `/tmp/kras-replay-future-final.log` |
| Existing save/migration/progression suite | 100 assertions passed | `/tmp/kras-replay-future-save-core.log` |
| Existing atomic-storage/byte-budget suite | 33 assertions passed | `/tmp/kras-replay-future-storage.log` |
| Actual recording/save/playback integration | 71 assertions passed | `/tmp/kras-replay-future-integration.log` |
| Compilation | 357 scripts passed | `/tmp/kras-replay-future-compile.log` |

All final processes exited zero and passed completed-summary/runtime/leak
guards. The future/storage/playback/compile logs contain no native ERROR or
SCRIPT ERROR lines. The core save suite deliberately triggers its existing
write-failure ERROR and asserts that dirty data can be retried; this expected
fault injection is retained, not an otherwise error-free log.

Protection tests exercise an already loaded newer main profile, a newer main
appearing during the session, and a newer backup appearing during the session.
Every attempted mutation compares original recording and future-envelope
bytes, checks the in-memory index, and verifies supported recording reads.
Fixtures use a nested isolated root and restore all original root/cache/dirty/
protection/index state before returning; no user's files are accessed.

## Remaining Qualification

These are lifecycle checks, not cross-process filesystem locking or a proof
against a future file appearing between a check and rename. Crash recovery for
orphan files/index reconciliation, power-loss/disk-full/mobile filesystem QA,
bounded long capture and all-game replay fidelity remain. Full CI, physical
device QA, exact-source release integration, Railway and App Store submission
are separate pending gates.
