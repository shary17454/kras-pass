# Tank pair-balanced campaign: invalid persistence evidence

Status: INVALID_SAVE_FAILURE. This is not balance acceptance or release QA.
Stage 0 remains QA_PENDING / MERGE_PENDING.

## Actual Execution

The current checkout and isolated runtime were fingerprinted before launch:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
The pair driver and schedule SHA256 matched between both directories.
No source was edited while the owned Godot campaign was running.

Godot 4.7.1, headless fixed 60 FPS, default tank arena, seed offset 96000000:
112 natural matches, 56 difficulty comparisons and two mutator smoke matches
completed. Process exit 0, elapsed 525.9 seconds. Start/end source fingerprints
match. The actual report confirms 56 appearances per character, 14 per seat,
and 24 coappearances for every character pair.

Reported Expert share was 0.5375, average simulated duration 16.3766 seconds,
and aggregate balance flags were empty. These numbers are diagnostic only:
the engine log contains 14 unexpected `[ERR][Save]` errors opening
`profile.json.tmp`. The campaign cannot qualify persistence or balance solely
from exit zero or an empty flag list. It must be repeated after fixing the
environment and verifying successful saves.

## Environment And Profiling

At failure diagnosis, `df -h /tmp` reported 153 MiB available on the 926 GiB
Data volume, capacity 100%. A later observation reported 244 MiB, still 100%.
Insufficient storage is a strong environmental explanation, not a proven
exclusive root cause or a claim that production player saves are broken.
No user files, historical evidence, certificates or archives were deleted.

The owned process continued after slow cases; it was never restarted merely
because observer output paused. A one-second `sample` completed but contained
only two main-thread samples with unresolved Godot symbols. Its 268.9 MiB
current / 1.6 GiB peak footprint cannot establish a leak, its cause, or iPhone
performance. No physical device, thermal or battery acceptance was performed.

## Corrective Gate

The previous log guard accepted the actual failed-save runtime log with exit 0.
A new regression initially failed (6 passing / 1 failing Node tests), proving
the false acceptance. The guard now rejects `[ERR][Save]` outside `tests` mode.
Unit save suites may deliberately inject unwritable destinations, but still
require a positive completed assertion summary. Known macOS CA warnings remain
separately tolerated; no gameplay thresholds or AI stats changed.

After correction: all 14 combined Node guard tests passed, zero skipped/failed.
The actual campaign log is now rejected with guard exit 1. This also protects
balance/stability/compile invocations from unexpected persistence errors.
Godot and full gameplay regressions were not rerun under the nearly full disk.

## Raw Evidence

- `/tmp/kras-tank-pair-96000000.engine`
- `/tmp/kras-tank-pair-96000000-report/report.json`
- `/tmp/kras-tank-pair-96000000-save/balance_progress.txt`
- `/tmp/kras-tank-pair-96000000-process-sample.txt`

Next: provide adequate free storage, verify isolated save writes, then repeat
the failed qualification. Do not insert this report into an accepted balance
index, clear previous warnings, promote READY, or deploy/release from it.
Main/Railway backup approval and current signed archive/upload/review remain
separate unresolved gates.

## Small Recovery Check

After Git access recovered, the gate correction was committed locally as
`8a72560b6b171bc1f87bf17b58b43e41a7f26de4`; no main push or deployment occurred.
Free space increased to 652 MiB, still reported at 100% capacity. No deletion
or cleanup was performed by this agent to produce that change.

The existing Godot save suite then completed with 111 assertions, exit 0,
against `/tmp/kras-storage-recovery-unit-save`. Its strict `tests` guard passed.
The sole emitted Save error belongs to the explicit `failed write stays dirty
and can be retried` fixture on `test_profile.json.tmp`; the suite verifies
retry, corruption recovery, backup failure, future-schema protection and
migration. Evidence: `/tmp/kras-storage-recovery-unit.engine`.

This small successful regression neither explains the previous runtime save
errors conclusively nor retroactively qualifies the 170-match campaign.
Large campaigns and the current Xcode archive still need sufficient storage.
