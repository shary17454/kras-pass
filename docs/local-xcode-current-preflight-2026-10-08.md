# Local Xcode 27 Current-Source Preflight

## Built Source

Compilation source: `f3b3c9cde96075ac173c59a16d8a581181641966`, tree
`758ad5e7e64812cc98a4bcf7eed4e8c183800713`.
Isolated detached checkout: `/tmp/kras-native-current-preflight-f3b3c9c`.
Repository: shary17454/kras-pass; source branch:
`fix/kras-ios-scene-source-evidence`. This is not main or a release commit.

The before-export source inspection includes the scene/addon guard from PR 214.
Input SHA256 is `d11f8555e51a257d5811a58808e8bd225baaab488ea7e488ceeb4a326e2e3774`.
Both source attestation recording and verification completed with exit 0 after
the export. No old game pack or Xcode export was reused.

## Native Bridge and Compilation

- Godot: 4.7.1.stable.official.a13da4feb.
- Xcode: local `/Applications/Xcode-27.app/Contents/Developer`, 27.0 (27A266a).
- iPhoneOS SDK: 27.0 (24A430).
- godot-cpp: `714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`, clean tracked tree.
- SCons: 4.11.1 from `/private/tmp/kras-apple-build-tools-112/bin/scons`.
- Current native bridge compiled for device arm64 and universal simulator;
  xcframework creation completed with exit 0. The existing pinned godot-cpp
  checkout was used, but the bridge and its library builds ran again.
- `tools/export_ios.sh device` completed with exit 0 and BUILD SUCCEEDED.
- Export: `/tmp/kras-current-f3b3-ios-export`.
- Logs: `/tmp/kras-current-f3b3-ios-evidence`.
- Release app:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.YaaQtzvlN4/Build/Products/Release-iphoneos/KrasPass.app`.

The exported and packaged PCK SHA256 both equal
`c021bac0644f74210b9de5f26dc1f7a13eb07e4c6c0b653f11e6abaa63a9d195`.
`nm` confirms `_kras_apple_init` in the executable. This proves linkage, not a
successful Apple authorization. `vtool` reports IOS, minimum 15.0, SDK 27.0.

## Actual App Metadata

Read from the built app, not just Xcode settings:

- Bundle ID: `com.shary.kraspass`.
- Version/build: 1.1.11 (110), unchanged development values, not a selected
  upload build number.
- iPhone and iPad supported; portrait and both landscapes declared, with
  upside-down portrait additionally declared for iPad.
- Controller interaction and multiple-controller declarations are enabled;
  these declarations do not prove physical controller compatibility.
- No `*UsageDescription` permission keys in the built Info.plist.
- Privacy manifest declares linked UserID for functionality, no tracking, and
  engine-required API reasons. This is manifest inspection, not a complete
  data-flow privacy audit.
- App size reported by the build script: 185M. This is not App Store download
  size, installed device footprint, performance or memory use.

## Diagnostics and Signing

The strict import/export log checker found no fatal diagnostics, but retained
the expected macOS errors for the temporary iOS-only extension. These logs are
explicitly not clean. The export trap removed the generated descriptor.
Xcode warned that AppIntents metadata extraction was skipped because the
framework is not used. There were no Xcode build errors.

`codesign -dv` reports the app is not signed, as expected with
`CODE_SIGNING_ALLOWED=NO` / `CODE_SIGNING_REQUIRED=NO`. No Archive, Distribution
signature, IPA validation, upload, processing or App Review submission occurred.
No P12 import, password request, certificate creation/revocation or Xcode Cloud
operation was performed.

## Generated Test UIDs and Next Source

Fresh import generated four untracked test UID files. They are under `tests/`,
excluded from the shipping iOS pack, and are not selected release inputs in
the attestation. This is why source verification passed, but the isolated
checkout is not claimed to have completely empty Git status after import.

Their real Godot-generated values were preserved in commit
`7293998c24bc90123c8c7f6265422a6d1017689f` for `test_ai_jump_actions`,
`test_driver_engagement`, `test_vehicle_dash_projection` and
`test_visual_roster_policy`. Import of the development checkout then completed
with exit 0, the strict log checker reported clean, and Git status was empty.
Gameplay fingerprint remained
`373ff382576009d42c54395613580fdf7acb0b017fa41c2afeead79e9ac9dd7e`.

Verifying the f3b3c9c export against the newer source correctly returned exit 1.
Do not label this compilation as an export of the UID or later documentation
commits. A final release source/version/build needs a fresh export and archive.

## Remaining Release Gates

The full current-gameplay gate is documented in
`ios-scene-source-attestation-2026-10-08.md`: 390939 Godot assertions, 229 server
tests with fresh world captures and all 39 stability games passed. These are
not physical iPhone/iPad thermal, battery, FPS or multiplayer acceptance tests.
Natural balance qualification is still incomplete and has an open Crumble
Court spawn warning. Production multiplayer is disabled and has not been
qualified with the current source.

Chrome was checked again and still displayed Apple login. The available build
inventory has not been completely refreshed. No build number was chosen or
changed without that check. No source was merged into main or deployed to
Railway during this preflight. Export/bridge/source summaries are retained under
`docs/qa/local-xcode-preflight-2026-10-08/`; full compiler logs remain at the
local evidence paths above.
