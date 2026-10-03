# Current core and local signing qualification

This is evidence for source `20a100101e027f9faaa2811e070718bb70106448`,
not an App Store release claim. Product source was not changed during this audit.
The evidence is on a separate documentation branch so publishing it does not
cancel the live PR #29 quality matrix or balance campaign.

## Completed current-source core CI

Game Quality run: `37146581097`, core scenario, successful job.
Actual PR merge checkout: `347460006b459441fa043aa8a1dea6c1adca0bd8`.
Recorded intended head: `20a100101e027f9faaa2811e070718bb70106448`.
Recorded tree: `9ff3f3fe156501d7445a0b36e94c3f7cf3e6a467`.

The recorded tree equals the intended head's Git tree, tracked changes are empty,
and run/scenario/intended-head metadata match. These values were checked against
the downloaded artifact and live local Git, not inferred from the job name.

Evidence root: `/tmp/kras-core-37146581097`.

- Full Godot test suite: **26734 assertions passed**, 178.2 seconds.
- Compilation: **324 scripts passed**.
- Stability: **117 matches, zero failures** (three cycles across 39 definitions).
- Server tests using six fresh actual Godot world captures: **179 passed**,
  zero failed/cancelled/skipped.
- Downloaded full-test and import logs pass the repository log guard.

This resolves the previous incomplete local exhaustive-test result for the
tested source. It does not certify physical touch layouts, thermals, battery,
balanced win rates, or the still-running complete multi-engine network matrix.
Stability checks are not a measurement of every full-length natural match.

## Natural balance: a warning remains

Campaign `37146577863` targets the exact intended head and seed offset `100000`.
The completed Ring Rumble artifact was verified by the report parser with all
39 expected IDs and partial=true. That audited subset contains 42 completed
matches (24 baseline, 16 matched difficulty, two stress), not the whole campaign.
Its complete=false and releaseReady=false are retained.

The 24 baseline seeds exactly match earlier campaign `37126402385`:

- Previous wins by slot: `[3, 4, 5, 12]`.
- Current wins by slot: `[3, 4, 5, 12]`.
- Slot bias remains **0.25**; warning remains `spawn slot advantage`.
- Difficulty pairs include all eight characters with mirrored Expert slots.

Evidence: `/tmp/kras-balance-37146577863-ring` and
`/tmp/kras-independent-balance-37126402385-api/natural-balance-ring_rumble`.
The annular Zone Hold fixes therefore cannot be presented as resolving this
separate warning. Remaining artifacts, including Zone Hold, must be inspected
after their actual jobs complete. No campaign was restarted due to observation
timeouts or queued status.

## Local signing and physical test gate

System-access commands confirm the current user's login Keychain and two valid
signing identities, including the requested:

`Apple Distribution: Shary ALADHYANI (4HM66AD594)`.

Xcode 27 devicectl now reports the physical iPhone 16 Pro Max as available and
paired. This supersedes older notes saying the phone was unavailable. No app
was installed during this audit.

All 73 local provisioning files decoded successfully. Three match the exact
bundle/team and Sign in with Apple entitlement:

- Both App Store profiles are unexpired through 2027-09-19 and include the
  requested Distribution certificate; no device list or get-task-allow.
- The Development profile is unexpired through 2027-09-06 and includes the test
  phone, but excludes the currently valid Development signing identity.
  It is not compatible with the intended physical-device test.

Refresh the existing Development profile to include the existing certificate;
do not create/revoke certificates or import a P12. The enabled browser tab still
shows Apple sign-in, so portal access has not been completed.

The read-only local checker is `/tmp/kras-local-profile-qualification.py`; it
prints compatibility booleans without private keys, passwords or certificate
payloads. It did not alter Keychain, certificates, profiles or devices.

Current checked-in iOS export settings: `com.shary.kraspass`, team `4HM66AD594`,
version `1.1.10`, build `107`. These are not accepted as final release numbers:
live App Store Connect inspection and a new suitable build number remain needed.

## Not completed

- All 39 balance reviews and current-source network matrix completion.
- Physical-device install, real interaction/performance/thermal qualification.
- Optional live Apple authorization and app-to-production connection.
- Final source integration and release version/build selection.
- A freshly sourced signed Archive, codesign/profile validation, upload,
  processing, build selection, review submission, or Apple approval.

Distribution identity/profile compatibility is not proof of any of those steps.
