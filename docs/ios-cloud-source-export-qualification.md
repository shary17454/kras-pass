# Current-source Xcode Cloud export qualification

## Defect and correction

The former post-clone hook assembled checked-in engine archive parts without
regenerating the game pack. A new Git checkout therefore did not prove that the
archived pack contained its game changes. The replacement hook builds the native
Apple bridge, exports the current Godot project, and verifies hashes for the game
pack, Xcode project, engine and bridge outputs against the committed source.

The first real integration export failed its source check: Godot generated 23
previously untracked script UID files. These identities are now committed, not
excluded from verification. A subsequent import generated no untracked release
inputs and changed no tracked source inputs.

## Verified local evidence, 2026-10-03

- Source: `55e1c1a90d97f67903b541b4dbadcc8df512db01`.
- Source tree: `c0118af923fe257487c9992b677ed62853a5013c`.
- Source fingerprint: `b172f9f8f458d5bc908d92a83b38f2641ad63dc6c2f067108da8edca9a4d8a41`.
- Test checkout: `/tmp/kras-cloud-export-uid-check`, with imported asset cache
  reused from the preceding clean-checkout integration test. It was not a cold
  import performance benchmark.
- Real post-clone hook: exit 0; 58 generated files hashed and verified.
- Repeat post-clone invocation: exit 0, verified cache hit without rebuilding.
- Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430), Godot 4.7.1.
- Generic iPhoneOS Release compilation: `BUILD SUCCEEDED`, exit 0.
- Actual app: `/tmp/kras-cloud-uid-derived-data/Build/Products/Release-iphoneos/KrasPass.app`.
- Actual bundle: `com.shary.kraspass`, version `1.1.10`, build `107`.
- Export and compiled-app PCK SHA-256 both:
  `7201530d63e50a59b4c4209d026546757b9fbe258ca7f25cbc8ed8863a6bb91a`.
- Native `_kras_apple_init` symbol defined in the actual executable.
- Actual plist declares iPhone/iPad and portrait/both landscape orientations.
- `codesign -dv` confirms unsigned output, as requested for compilation testing.
- 12 evidence/bootstrap unit tests passed, including generated UID preservation,
  dirty/untracked source rejection, changed outputs, malformed stamps, bad cache
  replacement and rejection of downloads with an incorrect checksum.
- Shell syntax and `git diff --check` passed.

Logs: `/tmp/kras-cloud-uid-export.log`, `/tmp/kras-cloud-uid-cache.log`,
`/tmp/kras-cloud-uid-xcodebuild.log`, `/tmp/kras-cloud-uid-unit-tests.log`.

## Tool download qualification and remaining gates

The real official template download exceeded its previous 900-second limit with
1,008,516,373 of 1,280,486,955 bytes received. Its retry was deliberately stopped
after that actual failure, retaining the partial file. A separate range-resume
test completed with a 3600-second limit; production download timeout is now
3600 seconds. The completed official TPZ checksum exactly matched
`86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72`.
Only then was it promoted to the cache. The tool helper subsequently completed
with exit 0 in temporary HOME, extracted the iOS template and ran the downloaded
`4.7.1.stable.official.a13da4feb` engine. Logs:
`/tmp/kras-ios-template-resume.log`, `/tmp/kras-ios-bootstrap-qualified.log`.
The range-resume operation was a test recovery, not behavior added to the helper;
the helper's uninterrupted fresh-template download with the longer limit still
requires remote Cloud validation. SCons and godot-cpp were supplied as explicit
local overrides in this bootstrap test, not freshly installed by it.

Commit `22002a8` changes that download timeout only, after the real export above.
It is not claimed as the source of the compiled application above. Any final
release must be exported again from its final version/build commit.

This is local execution of Cloud hooks, not a successful remote Xcode Cloud build,
signed archive, App Store upload, processing result or review submission. Build
107 is an existing preflight number, not a new release candidate. Final shipping
source, live App Store version/build selection, provisioning/signing, physical
device QA, complete game balance/network QA and production deployment remain
independent release gates.
