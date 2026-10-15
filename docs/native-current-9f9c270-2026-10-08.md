# Current-source local Xcode 27 preflight

Built commit: 9f9c27072fb20a5456db5915fab81fad6d627a1f.
Tree: 156b8c50f21bd337de862c32e2e42ce03820e501.
Input SHA256: a1bc7805a67112ef42456327a298fd98384220b6e0d83cb4fb11e8f76a709dfe.
Repository: shary17454/kras-pass, origin HTTPS, development branch
feature/kras-online-random-rotation. This is not a main/release promotion.
Detached source checkout: /tmp/kras-native-160fd13-preflight, advanced from
160fd13 to 9f9c270 before export to include two real Godot-generated shipping
script UIDs. Other untracked files in the development checkout were preserved.

## Build and source evidence

Local Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430), Godot 4.7.1.
Fresh godot-cpp checkout at the script's required
714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa; tracked tree clean.
SCons 4.11.1 installed in /tmp/kras-build-tools-160fd13, not system Python.
Bridge rebuilt for arm64 device and x86_64/arm64 simulator. The initial sandbox
attempt failed to create compiler temporary files (exit 2). The same build ran
successfully in the approved local macOS environment; no signing credentials
were imported, created, revoked or requested.

tools/export_ios.sh device: exit 0, BUILD SUCCEEDED, Release iphoneos arm64.
Export: /tmp/kras-native-9f9c270-export.
Before-export source receipt, record and verification all succeeded. Fresh
pack and linked bridge are covered by .kras-source-export.json; no old PCK or
export reused. Exported and packaged PCK share SHA256:
a7bbf086b3e415bba9bd97a17c2ebedbd113dd0e99b29e9373edc02eec09a61a.
nm confirms _kras_apple_init. vtool confirms IOS, minimum 15.0, SDK 27.0.

Actual built app:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.yeYqmVN2xB/Build/Products/Release-iphoneos/KrasPass.app.
Info.plist: com.shary.kraspass, 1.1.11 (110), iPhone/iPad, portrait and both
landscapes (additional upside-down portrait on iPad), multiple-controller
declarations. Values remain development values, not a freshly selected upload
version/build. No UsageDescription permission keys. Actual PrivacyInfo declares
linked UserID for functionality, no tracking, and engine-required API reasons.
This is metadata inspection, not native auth/controller/privacy acceptance.

## Diagnostics and limits

Import/export checker reports no fatal errors but retains the known iOS-only
extension/macOS editor diagnostics and clean=false. These are not clean logs.
Generated iOS descriptor was removed by the export trap. Test UID and doc
image-import files were generated outside shipping inputs; source verification
passed, but checkout status is not claimed completely empty after import.

codesign -dv exits 1: code object is not signed at all. Expected with
CODE_SIGNING_ALLOWED=NO and CODE_SIGNING_REQUIRED=NO. App size reported 192M,
not App Store download size or device memory/performance. No Archive,
Distribution signature, export validation, upload, processing or App Review
submission occurred; no Xcode Cloud used.

Raw bridge/build/import/export/Xcode logs, source receipts and actual app
metadata retained at ../qualification-native-9f9c270-2026-10-08/.
Runtime remains the Dodger repair fingerprint 4bcd0fb2fc4db5dd8df1c02b31065b182d12db0282d66ab61071eb9b7c982ed2:
392746 assertions and 430-script compile passed on that runtime. Expanded
Sweeper character imbalance remains. All-game source acceptance, physical
iPhone/iPad gameplay/energy/thermal QA, production migration/connectivity,
approved source promotion, refreshed Apple build inventory and frozen release
numbers are still required before a freshly signed Distribution archive and
separate upload/review verification.
