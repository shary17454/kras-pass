# Local Archive Including Gamepad Loss Fix

## Source

Repository: `shary17454/kras-pass`, origin HTTPS, branch `feature/kras-online-random-rotation`.
Verified remote source: `bc46d4e00bc842ad4aff17a8c17c198ea9370641`.
Tree: `f7abf211c551b023fc87ebe9a7ac5e33cb9ae430`.
Detached checkout: `/tmp/kras-native-bc46d4e-current`.
Release-input SHA256: `af405cdcdeb83e41385d0f634a965faa0ab507e905052d14f1f50c58f945f2c8`.

Fresh Godot iOS export: `/tmp/kras-bc46d4e-ios-export`. Source attestation was recorded and verified before archiving and verified after archiving/export. No tracked release inputs changed. Godot generated untracked test-script UID sidecars in the detached checkout; these are not release inputs or modifications to the authoritative checkout.

The Apple bridge was reused only after an empty `452f92f..bc46d4e` diff for native Apple sources and its build script. This is not a claim that the native bridge was newly compiled.

## Local Signing And Build

- Local `login.keychain-db` contains `Apple Distribution: Shary ALADHYANI (4HM66AD594)`.
- Selected Xcode 27.0, build 27A266a, SDK 27.0 (24A430), using per-command `DEVELOPER_DIR`.
- Release iphoneos settings: `com.shary.kraspass`, version `1.1.11`, build `110`, manual Distribution signing, team `4HM66AD594`.
- Installed and embedded App Store profile UUID: `91bc3a38-3753-4ed6-9f8b-a26974ff9d5e`; application ID, team and installed certificate match, `get-task-allow=false`, expiry 2027-09-19.
- No Cloud build, P12 import/password, certificate creation/revocation or global Xcode selection change.

Archive exit 0, `ARCHIVE SUCCEEDED`:
`/tmp/KrasPass-bc46d4e-1.1.11-110-qualification.xcarchive`.
Actual archived app plist matches the identity/version/build above.

Initial sandboxed codesign verification returned `CSSMERR_TP_NOT_TRUSTED`; sandbox CMS decoding also failed. Local system-permission reruns succeeded without changing certificates or trust settings. Both the failed sandbox logs and successful local logs are retained.

Local `codesign --verify --deep --strict` exits 0. Authority is the exact requested Distribution identity, followed by WWDR and Apple Root CA; TeamIdentifier is `4HM66AD594`.
Export/archive PCK SHA256: `64f536c228f6ebcf85190c15ea88e84ba41f9d79ae98f83be4306630adb43bd8`.
App/dSYM arm64 UUID both: `27C05167-0B3B-3AE6-9F3C-839CCF136F54`.
The export attestation and PCK, not the executable UUID alone, establish source provenance.

## Local IPA

`xcodebuild -exportArchive` exits 0, `EXPORT SUCCEEDED`, using explicit `destination=export`, manual signing, no automatic version/build change and no symbol upload.
IPA: `/tmp/kras-bc46d4e-local-distribution/KrasPass.ipa`.
IPA SHA256: `fcc367e1bbe3388cd0fe735ec992dd6d72c0b2532d55b391797724492bea30f8`.

The extracted IPA app passes local deep/strict codesign verification. Actual plist, embedded profile and PCK match the archive. Portrait and both landscape declarations exist for iPhone/iPad. PrivacyInfo.xcprivacy is present; camera, microphone, photo, location and contacts usage-description keys are absent. This is static package inspection, not physical-device permissions/layout QA.

## Open Gates

Godot export logs retain known iOS-only extension/macOS editor diagnostics: fatal=[] but clean=false. Logs are not claimed error-free.
Core run `37967296347` remains in progress on this exact commit at the latest inspection. Balance `37961516661` and network `37950626662` still use their captured older sources and are not qualification of the new runtime fingerprint.

This is a qualification build, not final product acceptance. No Apple upload, validation-service call, processing or review submission occurred. App Store Connect numbers were not refreshed in this archive-only pass; recheck before upload and use a new committed build number if required.
Device/controller/thermal/battery QA, balance review, unfinished product requirements, production backup/restore authorization, migrations and actual production connectivity remain open. No main merge or production mutation.

Evidence: `../qualification-native-bc46d4e-2026-10-09/` contains source/export attestation, export logs, settings, archive log, local and sandbox signature logs, PCK/plist/profile verification, dSYM comparison and local IPA export/packaging evidence. Full archive and IPA remain at the paths above.
