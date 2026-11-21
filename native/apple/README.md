# Native Apple account bridge

Objective-C++ GDExtension using AuthenticationServices and Keychain, iOS 18+.
The game remains Godot. No Flutter or SwiftGodot runtime is introduced.

Build with the selected Xcode, SCons 4.11.1 and official godot-cpp pinned to
`714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa` (Godot 4.4 stable ABI).

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer
GODOT_CPP_PATH=/path/to/godot-cpp SCONS=/path/to/scons bash tools/build_apple_bridge.sh
bash tools/export_ios.sh device
```

Build output: XCFramework with device arm64 and simulator arm64/x86_64 slices.
Artifacts are not checked into Git. The exporter temporarily creates an iOS-only
extension descriptor, adds Apple sign-in entitlements and system framework
linkage, then builds Release locally using Xcode 27 or newer. Export, signed
archive, signature verification, upload and App Review remain separate steps.

Keychain sessions are profile-scoped. Late responses after profile switches are
discarded. Server access does not alter earned progress. Deletion requires fresh
Apple confirmation and server revocation. No owner email is bundled in the app.

First owner login must share the verified owner email in Apple's authorization
sheet; Hide My Email cannot prove that original address. Subsequent logins bind
to the verified Apple subject, including when no email is returned.

Release gate: verify the existing provisioning profile includes Sign in with
Apple and matches the installed distribution identity. Do not replace a valid
profile or import a P12 unnecessarily. Test real sign-in/cancel/logout/delete
on a suitable signed device build. Verify the actual simulator engine slice
before running; bridge architecture support alone does not establish it.

`request_viewport_metrics()` asynchronously samples the foreground scene's root
view on the UIKit main thread and emits `viewport_metrics_received`. Its
normalized safe rectangle is available on iOS 18; active reserved occlusions
and divisions are queried only on iOS 27.1 or newer. Godot chooses a clear pane
and falls back to DisplayServer safe-area data if delivery fails. This does not
replace device testing for folding, rotation or native account overlays.
