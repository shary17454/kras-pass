# Local Xcode iOS Export Qualification

## Source and Tools

- Repository: `shary17454/kras-pass`, remote `origin`.
- Branch: `fix/kras-ios-export-import-gate`; not merged into `main`.
- Tested commit: `f6b9692466f66cacd65f448befff2a90eab43337`.
- Detached checkout: `/tmp/kras-ios27-export-gate-verify`.
- Godot: 4.7.1 official. Xcode: 27.0, build 27A266a. iPhoneOS SDK: 27.0.
- Generated import cache was reused. The existing native Apple framework was
  copied from the prior owned checkout; its device static library SHA256 is
  `a79acf56bfdad9e6577adc62bd0d51c38fa6593d462cc4208ed03234053fc3c1`.
  This is dependency equality, not proof of a fresh native bridge source build.

## Changes

Export evidence is written into an independent, initially empty directory.
Godot stdout is inspected before continuing. Unexpected engine errors, script
errors, import failures and leak diagnostics fail the gate. Exact macOS arm64
diagnostics for the iOS-only `kras_apple_runtime` extension remain visible and
are classified separately. A log containing these diagnostics is explicitly
**not clean**. No placeholder macOS extension was introduced.

## Verification

- `node --test tools/check-ios-export-log.test.mjs`: 4 passed, 0 failed.
- `bash -n tools/export_ios.sh`: passed.
- `git diff --check`: passed before the source commit.
- `tools/export_ios.sh device`: completed with exit 0 from the tested commit.
- Local Release arm64 compilation: `BUILD SUCCEEDED`; no Xcode Cloud build.
- Export project: `/tmp/kras-ios27-export-f6b9692/KrasPass.xcodeproj`.
- Evidence: `/tmp/kras-ios27-evidence-f6b9692/` contains import, export and
  Xcode build logs. Import reported 4 known platform diagnostics; export 7.
  Both inspections reported zero unclassified fatal errors and `clean: false`.
- Xcode's link command includes `-lKrasApple`; generated `dummy.cpp` registers
  `kras_apple_init`. This does not prove on-device authentication works.
- App: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.QvTuXvVvyX/Build/Products/Release-iphoneos/KrasPass.app`.
- App identity: `com.shary.kraspass`, version 1.1.10, build 107; SDK 27.0;
  iPhone/iPad, portrait and both landscape orientations, minimum iOS 15.

## Release Boundaries

This is an **unsigned compilation check**, not an Archive, verified distribution
signature, upload, processing result or App Review submission. Build 107 is
already distributed in App Store Connect and must not be reused for a new
upload. A new version/build and an integrated, frozen release source are still
required. No existing distributed version was withdrawn.

The live Railway health endpoint returned `ok: true`,
`authentication_ready: true`, `multiplayer_enabled: false`. That response does
not prove deployment source, database migrations, API/auth callback behavior or
end-to-end online readiness. No deployment was performed during this check.

The full 39-game natural balance campaign remains separate from this export
check. Device gameplay, performance, thermal/battery behavior, native bridge
runtime and final release qualification remain outstanding.
