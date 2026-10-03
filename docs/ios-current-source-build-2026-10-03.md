# Current-Source iPhoneOS Build Qualification

Source: `a217b976607fa17c28a2f09e3e2415c7692d2b49`.
Branch: `feature/kras-tank-visible-ammo`; origin: shary17454/kras-pass.
The local runtime checkout was verified against 371 source/config/native/tool
files plus 98 shipping assets: zero byte mismatches before export. Evidence:
`/tmp/kras-ios-current-source-proof.json`,
`/tmp/kras-ios-current-assets-proof.json`.

## Toolchain And Native Bridge

- Godot 4.7.1, Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430).
- godot-cpp `714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`, SCons 4.11.1.
- Fresh native bridge build succeeds for device arm64 and simulator arm64/x86_64.
  Log: `/tmp/kras-apple-bridge-current.log`.
- No P12 import, password request, certificate creation/revocation or signing
  operation was performed. The build tool selected Xcode via DEVELOPER_DIR.

## Export And Compilation

Fresh Xcode project:
`/private/tmp/kras-online-release/build/ios-export.fIDyhn/KrasPass.xcodeproj`.
Release app:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.iNRX72VT8P/Build/Products/Release-iphoneos/KrasPass.app`.

`tools/export_ios.sh device` completes with exit zero and BUILD SUCCEEDED.
Logs: `/tmp/kras-ios-current-export.log`, `/tmp/kraspass_xcodebuild.log`.
Actual built Info.plist: com.shary.kraspass, version 1.1.10, build 107,
minimum iOS 15.0, iPhone and iPad. The executable is arm64, built with SDK 27.0.
Phone orientations include portrait and both landscapes; iPad also includes
upside-down portrait. These declarations do not prove touch/layout QA.

The exported and bundled PCK SHA256 both equal
`26055d8ed319d9561e472870f249562beebc20bfe912afb50a690b351ed8e11c`.
The native `_kras_apple_init` symbol is defined in the final executable.
Its presence proves linkage, not a successful live Apple authorization.
The packaged privacy manifest declares linked UserID for app functionality,
not tracking, with tracking false and engine-required API reasons.

The importer logs a macOS system CA warning and missing macos.arm64 library
for the temporary iOS-only GDExtension. The iPhoneOS build succeeds; the desktop
descriptor is removed by the export trap. Xcode warns that AppIntents metadata
extraction was skipped because that framework is not used. No Xcode build
errors were found.

## Not Distribution Evidence

`codesign -dv` confirms this app is not signed, as requested by the compilation
script. It is not an Archive, validated IPA, upload or review submission.
Version/build 1.1.10 (107) are retained for this preflight only. A release needs
fresh App Store Connect version/build verification, a new build number where
required, a final committed source and a newly generated signed archive.

The physical iPhone 16 Pro Max remains unavailable in the current devicectl
snapshot. Simulator entries are not physical-device evidence. No other app's
devices/simulators were changed. Device performance, thermal, battery and actual
Apple sign-in remain unverified.

## Cloud Pipeline Risk

The checked-in build/ios/KrasPass.pck was last updated by commit
`5ed1a862da68865c2e047bc969d51b9bc6a28d76` (Prepare iOS build 105).
The current ci_post_clone hooks only restore engine libraries from archive
parts, not current Godot content or native bridge sources. Do not accept a
Cloud archive as current-source evidence until that pipeline regenerates and
verifies its content. The fresh local export above avoids the stale PCK, but
does not repair the Cloud pipeline.

## Ongoing Quality Gates

Matched balance campaign 37113379841 tests c97cd88 (same runtime code, older
documentation). Full core/network CI 37113428591 tests a217b97. Both were live,
not completed, when this build finished. Follow those exact run IDs; no duplicate
campaign was launched. Game balance, complete regression/network qualification,
release-source integration, Railway validation and physical-device QA remain
separate prerequisites before submission.
