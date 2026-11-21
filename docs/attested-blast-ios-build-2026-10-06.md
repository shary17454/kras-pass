# Attested Blast Ball Local iOS Build

This qualifies compilation of exact source
`4989c09cefa7e7c2788908eb96f12dc009aedfba` on
`fix/kras-blast-approach-budget`, not an integrated or submitted release.

## Source and Outputs

- Tree: `d14754dda5ba0a166b130b6a97a7b990c0e2bc1d`.
- Release-input SHA256: `500887f878f6907acf0c1da5abf2e357c3842ab54c763b73e44b83e56721b63a`.
- Pre-export snapshot: `/tmp/kras-ios27-blast-attested-before.json`.
- Export: `/tmp/kras-ios27-blast-attested-export`.
- Logs: `/tmp/kras-ios27-blast-attested-evidence` and
  `/tmp/kras-ios27-blast-attested-build.stdout`.
- App: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.B35fllNVnw/Build/Products/Release-iphoneos/KrasPass.app`.

`tools/export_ios.sh device` completed with exit zero and BUILD SUCCEEDED on
local Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430). No Xcode Cloud run was
started. The output is arm64, minimum iOS 15, device families iPhone/iPad.
`ios_export_evidence.py record` and `verify` both completed with exit zero,
against the pre-export snapshot. Source inputs and Git status remained clean.

The exported PCK and the PCK inside the built app both have SHA256
`f65fb2c04618e4d8672d8601eaf501429782af3db33b4a70adfc166aa6ad1c1b`.
No old gameplay pack was reused. The generated export contains its source and
output attestation in `.kras-source-export.json`. A later commit cannot silently
reuse this export as if it were a new attested release source.

## Native Library and Diagnostics

The previously freshly compiled native framework is reused; its tracked
Objective-C++ source is unchanged. Source SHA256:
`61ca541d6def86c5c0918ce0b338c2c0a5c70ca0eb5312b06c86e03a4dbdd134`.
Device static library SHA256:
`687c3e04947da83e44e0039f63c271402f1f139f1e2c3cb7c385b313b0e23749`.
Simulator library SHA256:
`96942d85006549ad3be4c2295ce573065d40da56d7550c692fac7ffa3b9240a6`.
The built app defines `T _kras_apple_init`, verified with `nm`.

The first hash-inspection command used nonexistent lowercase library/source
paths; the corrected actual filenames were inspected before qualifying them.
Known iOS-only extension diagnostics on the macOS editor are explicitly
retained with `clean=false` and no unknown fatal errors. They are not a clean
import/export-log claim and must not be described as errors silently removed.

## Identity and Release Limits

Identity was read from the built app's Info.plist, not inferred from settings:
`com.shary.kraspass`, version `1.1.10`, build `107`. iPhone declares portrait
and both landscape directions; iPad additionally declares upside-down portrait.
This is orientation metadata, not rendered layout or physical gameplay QA.
The packaged privacy manifest declares linked, non-tracking UserID for app
functionality; it does not establish every privacy requirement by itself.

`codesign -dv` confirms the app is not signed at all, as intended by the unsigned
build check. This is not an Xcode Archive, App Store Distribution signature,
TestFlight build, upload, processing result or App Review submission. The
already distributed version/build are intentionally unchanged and must not be
uploaded as a new candidate. Final integration, new version/build selection,
current-source release gates, signing/profile validation and a new Archive
remain necessary before upload.
