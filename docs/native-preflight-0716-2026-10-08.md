# Current Runtime Local Xcode Preflight

Built commit: `0716a6a5b94db42c538d6d126451d91219e8f0b3`.
Checkout: `/tmp/kras-native-preflight-0716a6a`, detached and initially clean.
Tree: `fc88eb925d5046467ffde35e4c0f4dfe5f9f48e8`.
Inputs SHA256: `65002ea2002b8af63389011ecc51b9c91de3319b846fddf8a9c0488d021e6715`.
This is a preflight source, not a frozen published release commit.

## Local Build

- Official Godot 4.7.1, local Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430).
- A fresh Godot project and PCK were exported, then Release compilation passed.
- Existing bridge libraries were reused from the earlier local preflight,
  **not rebuilt**. Tracked bridge source and build script are unchanged from
  f3b3c9c; copied device library SHA256 matches
  `b8b87ae49b4c87b100bd8a0c72960217c0cd6cf222e21e06fbd6f174f70956ac`.
- Source recording and output verification both exited zero after export.
- Export: `/tmp/kras-preflight-0716-ios-export-retry`.
- App: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.pKClerWcFg/Build/Products/Release-iphoneos/KrasPass.app`.
- Actual app metadata: `com.shary.kraspass`, 1.1.11 (110), arm64, minimum iOS 15,
  iPhone and iPad, portrait and both landscapes; iPad also declares upside-down.
- Export and packaged PCK SHA256 both equal
  `a299bbd4bd03e6411d86c3c0497aa1b2860a28b3ad4d6b248f015a891e1bc5c5`.
- Built app declares multiple controllers and has no permission usage strings.
  Declarations alone do not prove actual device/controller acceptance.
- App size 185M is a local bundle measurement, not App Store download size.

## Failed First Attempt

Fresh initial import crashed with exit 134 / signal 11 while importing fonts,
with an off-thread `propagate_notification()` error. The retained original log
is not described as passing. A subsequent normal import without the generated
iOS-only extension completed, exited zero and passed the strict import guard.
The second export completed with the existing checker retaining the known
iOS-only macOS extension diagnostics; its logs are explicitly **not clean**.

Godot's upstream [issue 111039](https://github.com/godotengine/godot/issues/111039)
documents a similar concurrent font-import crash, addressed on master by
[PR 123546](https://github.com/godotengine/godot/pull/123546). This is supporting
context, not a proven root-cause diagnosis for this binary. No engine change,
cache commit, error suppression or import-guard weakening was performed.

`ios_export_evidence.py --help` initially failed because that script takes
positional mode/root/output arguments. Correct `source`, `record`, `verify`
invocations completed; the failed help probe is not a failed compilation.

Retained source/export/import and balance records:
`qa/native-preflight-0716-2026-10-08/`. Full compiler log:
`/tmp/kras-preflight-0716-ios-evidence-retry/xcodebuild.stdout`.

## New Natural Campaign Evidence

Campaign 37721855569, source 50539cbe, runtime fingerprint 523906225b6e...:
Ring Rumble and Crumble Court each completed 24 baseline matches, 16 matched
difficulty comparisons and two stress variants. Source start/end agree, source
records match the campaign commit, and retained import/runtime log guards pass.
Both samples have zero flags; Expert edge is 0.600 and 0.575 respectively.
Crumble's prior 96-match current-source spawn warning remains in the sample
history index despite this later clean sample. This does not mark content READY.

## Not Performed

Signing was intentionally disabled. `codesign -dv` confirms no signature.
No Archive, IPA, Distribution validation, install, upload, processing or review
submission occurred. Version/build were unchanged development values, not a
new upload-number selection. No certificate/P12 operation or Xcode Cloud was
used. Main is unchanged. All-game balance/device/production/release gates remain.
