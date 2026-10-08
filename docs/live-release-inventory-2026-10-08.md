# Live Release Inventory

Read-only inspection on 2026-10-08, after the user completed Chrome sign-in.
This records current observations, not upload or release qualification.

## Apple

App Store Connect app: `Kras Pass`, app ID `6801506973`.
Authenticated navigation was verified by opening Build Uploads, Distribution,
and App Review, not just by reading a cached signed-in header.

- TestFlight latest version group visible: `1.1.10`, build `107`,
  `Ready to Submit` (beta status), expiring in 80 days.
- Build Uploads latest visible entry: `1.1.10 (107)`, `Complete`,
  September 28, 2026, 1:35 AM as displayed by Apple.
- Other visible uploads: `1.1.9 (106)`, `1.1.8 (108)`, `1.1.8 (104)`,
  `1.1.7 (99)`, all Complete. No `1.1.11` version group was visible.
- Distribution: `1.1.10`, `Ready for Distribution`, selected build `107`.
- App Review visible list contains completed and removed submissions;
  latest September 28, 3:25 AM, `iOS 1.1.10`, `Review Completed`.
  No pending new submission was displayed on that page. This is a UI
  observation, not an assertion about hidden API records.

No metadata, version/build value, upload, selected build, review submission,
withdrawal, or release setting was changed. No Xcode Cloud was opened or used.
The completed old upload does not establish the source of a future archive.
Choose and commit the new Version/Build only after source acceptance and
another inventory check immediately before the new local Xcode archive.

## Git And Production

HTTPS fetch of `origin/main` completed successfully. The remote main reference
remains `062a40992b92958573e28e19d8c8c1840560797a`.
Current candidate is on `fix/kras-platform-shortest-route-ties`, not main.
No merge or production promotion was performed.

Fresh public Railway health response:
`{"ok":true,"authentication_ready":true,"multiplayer_enabled":false}`.
This establishes service health, not actual native positive authentication,
database backup/restore qualification, correct current deployment source,
or production online gameplay. Online remains disabled in production.
No production database, environment variable, or deployment was modified.

## Gates Still Open

Candidate balance warning remains under matched held-out investigation.
Current all-game qualification, physical-device gameplay/performance/energy
acceptance, approved production rollout and exact-source signed local
Xcode 27 archive remain required. Upload, processing and review submission
must be verified independently; none occurred in this inspection.
