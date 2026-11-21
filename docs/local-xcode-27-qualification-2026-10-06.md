# Local Xcode 27 Qualification

## Source and Toolchain

Repository: `shary17454/kras-pass`, remote `origin`.
Qualification branch: `fix/kras-local-xcode-release-resources`.
Runtime/export source: `1242fd45cb2bb719f68a5bfc4904e222e6aea5c2`.
Source tree: `4009d60b8851027c4d7482ea6a2f16a59c0c61f8`.
Input digest: `c7c199862898b78fbb000fbef12361fc588deba324019098aa9e628d9ccd7cc0`.

Local toolchain: `/Applications/Xcode-27.app/Contents/Developer`, Xcode
27.0 build `27A266a`, iPhoneOS SDK 27.0 (`24A430`). Godot is 4.7.1
official `a13da4feb`. No Xcode Cloud job was used for this build.

The native Apple bridge was freshly rebuilt for device and simulator against
godot-cpp `714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`.
Log: `/tmp/kras-local-xcode-bridge.log`.

## Resource Correction

Both application export presets now explicitly include all five original font
license files. The exported PCK was loaded separately and all five licenses were
found with their original SIL license heading. The font suite passes 843
assertions; its runtime log guard also passes.
Log: `/tmp/kras-local-xcode-font-suite.log`.
The iOS export evidence unit tests pass all 12 tests.

The global bundled theme probe reached 51,360,635 tracked static bytes with
labels alive, versus 243,476,215 in the earlier explicit-font-only probe.
This is a headless macOS text allocation comparison, not physical-device RAM,
FPS, battery or thermal qualification. No live TextServer cache eviction was
added. Report: `/tmp/kras-local-theme-memory-save/font-memory.json`.

## Current-Source Local Build

Fresh export: `/tmp/kras-local-xcode-export-1242fd4`.
Its `.kras-source-export.json` was recorded against the source identity above,
then verified successfully without changing release inputs.
PCK SHA-256: `c272492a5932b30865c201e93b33da3e0776ebc5746941f59d09d21cd7266056`.
Export log: `/tmp/kras-local-xcode-export-1242fd4.log`.

Local `xcodebuild`, scheme `KrasPass`, Release configuration, `iphoneos`, generic
iOS destination, completed with `BUILD SUCCEEDED`. The built application is:
`/tmp/kras-local-xcode-derived-1242fd4/Build/Products/Release-iphoneos/KrasPass.app`.
Its Info.plist reads `com.shary.kraspass`, version `1.1.10`, build `107`.
The binary's LC_BUILD_VERSION confirms SDK 27.0 and minimum iOS 15.0.
Log: `/tmp/kras-local-xcode-release-1242fd4.log`.
This compilation used `CODE_SIGNING_ALLOWED=NO` and is not a Distribution
archive, signature verification, TestFlight upload or App Review submission.

The iOS-only GDExtension reports no desktop library during the exporter's
macOS editor import. The export and iOS native compilation completed; this
message must not be represented as a clean desktop import result. Sandbox
editor-setting writes and system CA enumeration also produced environmental
diagnostics in isolated probes.

## Signing Prerequisites

The local Keychain contains `Apple Distribution: Shary ALADHYANI (4HM66AD594)`,
SHA-1 `C81811A21B592B030D57CD5B180227BDDADEA4C1`.
Profile `91bc3a38-3753-4ed6-9f8b-a26974ff9d5e` matches
`4HM66AD594.com.shary.kraspass`, contains this certificate, disables debugging,
permits Sign in with Apple, and expires 2027-09-19.
No P12 import, password request, new certificate or revocation occurred.
Usable signing prerequisites are not proof that this app has been signed.

## Production and Open Gates

Railway deployment `8d235c0c-eac1-4ade-9065-4e3264d36021` is `SUCCESS`, source
`main` at `062a40992b92958573e28e19d8c8c1840560797a`. Its effective health gate
is `/health` with a 100-second timeout. Live health returned `ok=true`,
`authentication_ready=true`, `multiplayer_enabled=false`. A bounded log sample
contained six informational startup entries, not proof of all API or database
paths. The unmerged resource fix is not deployed to production.

The earlier native portrait capture `/tmp/kras-bundled-font-portrait.png` was
visually inspected: text glyphs are visible, but player cards cover too much
of the arena and the role banner overlaps them. This is an open layout gate;
it is not a newly qualified portrait build of the source above.

The full regression run passed 361,897 assertions in 980.9 seconds, exit zero,
and passed the runtime log guard. The first real-time invocation was
intentionally stopped (exit 143); it is not a passing run. Its replacement used
the existing fixed-step test pattern `--fixed-fps 60` and isolated save storage.
Log: `/tmp/kras-local-xcode-full-fixed-tests.stdout`. This suite does not replace
rendered layout QA, physical-device performance testing, Internet sessions, or
complete product acceptance. The source remained unchanged during this run.

Release remains incomplete: visual polish, complete product acceptance,
physical iPhone/iPad gameplay and thermal checks, production online validation,
current App Store Connect version/build inspection, a new build number,
consistent internal version, exact-source signed Archive, codesign validation,
upload, processing and review submission are still required. No existing
App Store review was withdrawn during this qualification.
