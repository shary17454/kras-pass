# Tank spawn matrix and source access

Status: RUNTIME_DIAGNOSTIC_PASSED / CHECKOUT_ATTESTATION_PENDING.
Stage 0 remains QA_PENDING / MERGE_PENDING; no READY or release acceptance.

## Regression Extension

The existing spawn-clearance suite now covers tank_foundry, tank_oasis and
tank_frost. Two quartets include all eight characters and are rotated through
all four seats on each tank map. This adds 24 tank scene configurations and
96 character/seat/map observations, each checked for static-body intersection
and membership in the playable arena. The five earlier non-tank cases remain.

The first extension with fixed quartets passed 129 assertions. The final
all-seat matrix passed 273 assertions in 15.3 seconds, process exit 0. Both
final logs passed the strict completed-test guard. No gameplay, stats, AI,
spawn positions or thresholds were modified.

The new fixture SHA256 matches in checkout and isolated runtime:
`7d6ff13a16ae6ccc6e55ed2b73bfd59816ad0d5f633d64da672fc84bf9d3c388`.
The isolated runtime fingerprint was freshly read as
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
The whole checkout fingerprint did not complete, so these results are scoped
to that runtime and the identical fixture, not a newly qualified release.

The test only freezes fighters at authored starts and queries real collision
geometry after physics synchronization. It does not prove long-term movement,
balanced line-of-sight, equal pickup access, fair winners or device performance.
No direct initial obstacle overlap was found in this matrix; that hypothesis
does not explain the earlier Oasis warnings by itself.

## Incomplete Oasis Campaign

The interrupted 2026-10-12 stdout includes warnings for spawn-slot advantage
and Expert no better than Easy, but no final report JSON is available. Its
process/session no longer existed at the earlier pause. Preserve its logs;
restart a fresh campaign only after source access is reliable, rather than
treating the partial summary as an accepted result or deleting the warnings.

## Current Filesystem Blocker

Finder visibly reports full iCloud storage and quota/sync errors on project
files. The local Data volume had 8.1 GiB available at resume; cloud quota and
local free storage are separate observations.

The checkout reader progressed from bake_original_music.tscn to
bake_original_sfx.tscn. The latter had compressed,dataless flags. A native
FileManager download request and Finder Download Now were issued only for
existing project files. SFX scene later became local without those flags.
No account settings, purchase, permanent deletion or source replacement was
performed. An unintended Finder paste was undone; a direct directory listing
confirmed no textClipping file remained.

The fallback git archive of commit
`76462f06cd342daf5eb74eeda345f3091533cae5` then waited on .git/HEAD, which remained
hidden,compressed,dataless. A download request for that existing metadata file
was issued, without writing its contents or reconstructing Git.

The two redundant fingerprint readers and the unsuccessful archive attempt
were explicitly terminated (exit 143), not mistaken for terminal on an
observer timeout. The redundant filename search was also closed. No completed
checkout fingerprint or frozen source archive is claimed. Do not use any
partial tar output as source evidence. Root Git metadata was not repaired,
recreated, replaced, or initialized.

## Evidence And Next Action

- `/tmp/kras-tank-spawn-clearance-2026-10-13.stdout` and `.engine`: 129 assertions.
- `/tmp/kras-tank-spawn-all-seats-2026-10-13.stdout` and `.engine`: 273 assertions.
- `/tmp/kras-tank-oasis-pair-2026-10-12.stdout`: incomplete natural campaign.

Make the selected project's cloud-backed source and Git metadata fully local,
then recheck status/diffs/HEAD and fingerprint before qualifying new campaigns.
The suite edit and this document are saved as files but not committed while
HEAD access is pending. No push, Railway deployment, Xcode archive, Apple
upload or review submission occurred. The remaining balance, full QA, device,
production backup/restore and release gates are still open.

## Local Xcode And Subsequent Access Check

The installed `/Applications/Xcode-27.app` was checked directly, not inferred
from its name: Info.plist reports 27.0, and xcodebuild reports Xcode 27.0,
build 27A266a. With command-scoped DEVELOPER_DIR, the iPhoneOS SDK reports 27.0.
No global xcode-select setting, license acceptance, Xcode Cloud, signing or
archive action was performed. This confirms the requested local toolchain,
not successful app compilation, signing, upload or review.

HEAD initially became local, and git log returned
`76462f06cd342daf5eb74eeda345f3091533cae5` / Update project. However, Git status
then waited on .gitattributes and the fingerprint reader on the music scene.
Explicit FileManager download requests were issued for those two existing
files only; their dataless flags subsequently disappeared. HEAD's dataless
flag reappeared in that same follow-up. Local availability is therefore not
stable enough to freeze a release. The reason for this reappearance was not
established; do not attribute it conclusively to a particular system setting.

Local free space was 3.6 GiB at this check. The two remaining read processes
were explicitly closed with exit 143 after documenting this condition, without
restarting them just because observation timed out. No completed git status,
whole-checkout fingerprint, new commit or push is claimed for this follow-up.
The previously asked cloud-storage/local-copy question remains unanswered.
