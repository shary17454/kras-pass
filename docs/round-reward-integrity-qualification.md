# Round reward integrity qualification

Date: 2026-10-03.
Base: `d2f1c6af1e46dc578a2e501ec697e307d987a63a`.
Branch: `feature/kras-round-reward-integrity`.
Code commit: `1072fb8c29d76828adb96d83f029020a2197aba3`.

## Findings and fixes

`MatchResult.aggregate()` previously left `finished_naturally` true when an
input round was interrupted, and even when the round list was empty. The
statistics service correctly rejects aborted results, but could not reject
these aggregates because their completion flag had already lost that fact.

The aggregate now preserves interruption from any round; an empty aggregate
is not a completed match. `MatchScene._complete_match()` combines this flag
with the scene's own abort status instead of overwriting it. Scores, details
and round references remain available for diagnostics and results flow.

The flawless-win counter previously accepted a shared first-place draw as a
round win. It now requires every round to have finished naturally, placed the
player first, and not been a draw. An overall victory still counts as a normal
win when one constituent round was drawn.

Existing earned saves are not reset or rewritten. This changes future reward
eligibility only; it does not attempt to revoke potentially legitimate past
achievements from data that cannot prove how they were earned.

## Regression evidence

Godot: `/Applications/Godot.app/Contents/MacOS/Godot`, 4.7.1.
Runtime copy: `/tmp/kras-cloud-export-uid-check`.
All six changed source/test files were byte-compared with this branch and
matched. The runtime checkout's older Git HEAD is not release provenance.
Each invocation used `--headless --fixed-fps 60` and a separate
`--test-data-dir`; no player's real save was used.

Before the production changes, the new scoring fixtures produced 45 passing
and 2 failing assertions. The profile/reward fixtures produced 70 passing
and 6 failing assertions, including incorrect statistics, gems and first-win
unlock after an interrupted aggregate. Some later counter failures in that
baseline are cumulative consequences of the preceding incorrect reward.

After the changes:

| Check | Result | Log |
| --- | --- | --- |
| `--suite=scoring` | 47 assertions, exit 0 | `/tmp/kras-reward-fixed-scoring.log` |
| `--suite=party_progress` | 76 assertions, exit 0 | `/tmp/kras-reward-fixed-party.log` |
| `--suite=lifecycle` | 13 assertions, exit 0 | `/tmp/kras-reward-fixed-lifecycle.log` |
| `--suite=save` | 100 assertions, exit 0 | `/tmp/kras-reward-save.log` |
| `--suite=matches` | 6958 assertions, exit 0 | `/tmp/kras-reward-matches.log` |
| `tests/compile_check.tscn` | 324 scripts compile, exit 0 | `/tmp/kras-reward-compile.log` |
| `git diff --check` | passed | local command output |

The lifecycle fixture calls the real scene completion path and captures its
callback; the interrupted result stays ineligible and the scene reaches DONE.
The matches suite completed in 1388.8 seconds of wall time, including every
registered minigame, three-round aggregation, pause/restart/quit, controller
loss and authored race recovery rules. Its standard arena rounds deliberately
use shortened five-second settings (and existing sudden-death rules), not full
production-duration balance samples. The extended-race section separately ran
three actual AI laps on all eight circuits, with no gameplay countdown. This
proves those integration fixtures pass, not all device QA scenarios or player
counts/orientations. Total assertions across the five selected suites: 7194.
The existing profile fixtures still check exactly-once tournament receipts,
restored cups, guests, profile ownership and replay cosmetics. Save corruption
and denied-write warnings/errors in the save suite are deliberate fixtures,
not evidence of a production filesystem failure.

## Release gates still open

This is not a complete requirement audit or release approval. The independent
39-game balance campaign `37126402385` remained live at the latest observation
(19 successful jobs, no failed jobs, other jobs pending or running). Its source
is the base above and its seed offset is 100000; this reward-only branch does
not change simulation rules or substitute its own results for that campaign.

Main Game Quality run `37127102177` is also live for the base above. The older
main run `37123008553` was cancelled after the user-authorized main push; it
must not be reported as a completed success.

Full current-source network qualification, balance review, physical iPhone
performance/thermal/orientation QA, production Railway synchronization and
API verification, and a new source-proven signed Archive/upload/review remain
separate requirements. No Archive, signing, upload or Apple submission was
performed by this change.

## Physical-device and signing prerequisites

Xcode 27 `devicectl device info details` successfully reached the paired
physical iPhone 16 Pro Max (iOS 27.0.1): developer mode enabled and tunnel
connected. No app was installed or launched in this prerequisite check.
The diagnostic JSON is `/tmp/kras-round-reward-physical-details.json`.

An escalated local macOS query found the user's login keychain and two valid
signing identities, including the requested Apple Distribution identity for
team `4HM66AD594`. No P12 import, password request or certificate changes
occurred. A standard plist parser decoded all 73 installed profiles with zero
decode failures. Three profiles matched `com.shary.kraspass` exactly:

- Both existing App Store profiles include the requested Distribution
  certificate and team, expire on 2027-09-19, and disallow get-task-allow.
- The installed development profile includes the physical device and team,
  but not the currently valid Apple Development identity shown by Keychain.
  Therefore it does not yet prove an installable development-signed device
  build. Updating that profile to an existing compatible identity is separate
  from creating a certificate; do not create/revoke certificates to bypass it.

The first attempted profile inspection used `plutil` JSON conversion, which
cannot represent all certificate/date plist types. Its empty match output was
not treated as proof of missing profiles; the standard plist parser above
resolved that observation. Keychain/profile availability is not Archive or
codesign success, and actual device gameplay/performance QA remains undone.
