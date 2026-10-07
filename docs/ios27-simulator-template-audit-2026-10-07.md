# Local Xcode 27 Simulator Template Audit

This is a read-only investigation, not a simulator run, a device performance
qualification, or an App Store archive acceptance.

## Verified Local Inputs

- Xcode directory: `/Applications/Xcode-27.app/Contents/Developer`.
- Installed engine export template:
  `~/Library/Application Support/Godot/export_templates/4.7.1.stable/ios.zip`.
- Template member inspected:
  `libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a`.
- Read-only extracted copy:
  `/tmp/kras-official-471-release-simulator-readonly.a`.
- Existing frozen candidate export comparison:
  `/tmp/kras-candidate-111-ios-export/KrasPass.xcframework/ios-arm64_x86_64-simulator/libgodot.a`.

Both static libraries have SHA-256
`50d00a3bb22c998e78dd30ccc5546283add7553cc086940f77d2454401c7066e`.
`lipo -info` identifies the extracted template library as non-fat **x86_64**.
The candidate XCFramework metadata advertises arm64 and x86_64 for that simulator
slice, but metadata does not supply the missing architecture. The export did
not remove an arm64 slice: its library is byte-for-byte identical to the
installed template's library.

## Runtime Compatibility

An initial sandboxed `simctl` query failed to reach CoreSimulator and its log
directory. A subsequent authorized local-system read-only query succeeded;
the service is not proven broken by the sandbox failure.

With explicit Xcode 27 `DEVELOPER_DIR`, installed runtime metadata reports:

| Runtime | Available | Supported architectures |
| --- | --- | --- |
| iOS 18.6 | yes | x86_64, arm64 |
| iOS 26.4 | yes | arm64 |
| iOS 26.5 | yes | arm64 |
| iOS 27.0 | yes | arm64 |

Two installed iOS 27.0 entries report the same arm64-only architecture.
The current x86_64 engine simulator library cannot establish an arm64 iOS 27
simulator launch. Merely forcing `-arch x86_64`, as the export helper currently
does for simulator builds, is not proof of compatibility with that runtime.
An iOS 18.6/Rosetta attempt would be a separate compatibility test, not iOS 27
qualification and not an energy/thermal test on physical hardware.

## Next Gate

Obtain or reproducibly build a compatible Godot 4.7.1 arm64 simulator engine,
verify actual architecture and platform, then use a fresh current-source export
and isolated simulator for native UI/gameplay QA. Do not patch framework
metadata to claim an architecture that the binary lacks.

No installed templates, existing exports, frozen archives, certificates,
provisioning profiles, Keychain entries or physical-device apps were changed.
This simulator finding does not invalidate the separate device-arm64 archive
signature, and that older archive still cannot represent later source changes.
No upload or review submission occurred.
