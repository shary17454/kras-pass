# Native Apple account bridge

Objective-C++ GDExtension using AuthenticationServices and Keychain, iOS 15+.
The game remains Godot. No Flutter or SwiftGodot runtime is introduced.

Build with the selected Xcode, SCons 4.11.1 and official godot-cpp pinned to
`714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa` (Godot 4.4 stable ABI).

```sh
GODOT_CPP_PATH=/path/to/godot-cpp SCONS=/path/to/scons bash tools/build_apple_bridge.sh
bash tools/export_ios.sh device
```

Build output: XCFramework with device arm64 and simulator arm64/x86_64 slices.
Artifacts are not checked into Git. The exporter temporarily creates an iOS-only
extension descriptor, adds Apple sign-in entitlements and system framework
linkage, then builds Release without overwriting the tracked Cloud project.

Keychain sessions are profile-scoped. Late responses after profile switches are
discarded. Server access does not alter earned progress. Deletion requires fresh
Apple confirmation and server revocation. No owner email is bundled in the app.

First owner login must share the verified owner email in Apple's authorization
sheet; Hide My Email cannot prove that original address. Subsequent logins bind
to the verified Apple subject, including when no email is returned.

Release gate: regenerate provisioning with Sign in with Apple, install a signed
build, and test real sign-in/cancel/logout/delete. The bundled Godot simulator
engine is x86_64-only; the bridge supports arm64 too. Compilation is not a device test.
