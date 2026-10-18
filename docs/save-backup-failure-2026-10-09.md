# Save Backup Failure And Source Qualification

## Corrected persistence failure

Starting checkout: 0492fe3 on feature/kras-online-random-rotation.
The previous SaveSystem replaced main and cleared pending progress even when
its backup could not be written. An isolated fixture with a directory occupying
the backup destination reproduced two failed assertions before the fix.
The red fixture also attempted to read an absent backup; the final fixture
guards its type before inspecting it. The original failure log is retained.

Backup writes now use a separate .bak.tmp file, flush and check write errors,
then atomically rename the backup before replacing main. Failure in reading,
staging or replacing the backup returns false, preserves main and keeps the
slot dirty for retry. The valid existing backup is not truncated by a failed
staging write. Save schema remains 2; no migration or gameplay change.

Regression tests cover blocked backup destination, blocked backup staging,
byte preservation of both good files, pending progress and successful retry.
Targeted save suite: 111 assertions, exit 0. Full fixed-fps 60 suite:
406164 assertions, 291.7 seconds, exit 0. Both full stdout and engine log passed
tools/check_godot_log.sh in tests mode. git diff --check passed.

The first full invocation omitted fixed-fps. It was intentionally stopped
with SIGINT (exit 130) after discovering the invocation mismatch; it is not
counted as a completed or qualifying full run. Its logs are retained alongside
the red, targeted green and completed fixed-fps logs:
../qualification-save-backup-2026-10-09/.

New runtime fingerprint:
274d1649bf08d310aab79374014795d542e687e47d2680975398598187ad1774.
The prior native archive from 3863e7c does not include this fix. A new documented
archive and current-source qualification are required before uploading it.

## Completed prior-source balance campaign

Run 37950278256 finished successfully with 41 successful jobs, head
b5e4f9e7d61c3dedbb6e79b6741ebf86f57a9c69, seed offset 8300000, fingerprint
53cde46b50cf16a86a63439072b716dfbf475238dfca1ef42a671d5bc384b552.
Downloaded artifacts independently passed tools/balance-report.mjs with the
expected source, paired samples and seed: 39 games, 1638 completed natural
matches, no missing games, source and pairing verified. All 117 raw stdout/log
files passed the strict checker with import/runtime modes.

Retained reviews: blast_ball, goal_guard and sweeper_storm difficulty separation;
mukharrib and sky_court spawn advantage. balanceReviewComplete and releaseReady
are false. A successful campaign does not remove prior cohort warnings or
prove device performance. This campaign predates the save fix and cannot be
silently relabeled as new-source evidence.
Raw campaign and verified summary:
../qualification-balance-b5e4f9e-complete-2026-10-09/.

No main merge, production deployment/migration, device replacement, archive,
upload or App Review submission was performed in this batch.
