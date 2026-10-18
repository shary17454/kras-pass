# Current Fuse Source Qualification

Inspected and built commit: `7f270c506650ea8dbe780df539fc0d316bdddf4a`.
Branch: `fix/kras-blast-visible-fuse-age`; repository: shary17454/kras-pass.
Runtime fingerprint:
`160a0600b0616ed7e26dc2706782afdec832130ea902dd46caf3fb20ab7af1c1`.
Evidence directory: `qa/fuse-source-qualification-2026-10-08/`.

## Independent Natural Sample

Blast Ball, offset 2400000: all 96 baseline attempts and 48 paired difficulty
comparisons completed naturally, using the authored 90-second round window.
Both stress smoke checks completed. Source fingerprints at start/end match.
Expert placement share: 0.529166666666667; slot wins: 22, 24, 31, 19;
mean duration: 22.0128472222222 seconds; flags: none.
Engine exit and existing runtime log guard passed.

Verified no baseline or paired seed overlap with the earlier offset 1800000
candidate. The two reports contain 192 baseline matches and 96 paired
comparisons, but their rank-share metrics were not summed or treated as a
population-level guarantee. No rules, profiles, thresholds or runtime files
were edited in this qualification pass.

## Actual Renderer Checks

Official Godot 4.7.1, Metal Forward Mobile renderer on Apple M5.
Arabic and English each completed 78 captures: every one of the 39 catalogue
entries in landscape and portrait. Zero failures; both engine exits and
runtime log guards passed. Verified every expected game/orientation pair,
saved PNG existence, control bounds, one requested human slot and phase
PLAYING. All four competitors were alive in every capture.

Scope: default arena, one scripted human slot plus three AI, two additional
play seconds after legal lifecycle transitions. This is not a physical-human
playtest, all-map coverage, sustained FPS, phone energy or thermal acceptance.
PNG hashes/dimensions are retained for all 156 captures. Representative actual
images reviewed and retained: Tank Arena in both orientations, Arabic Blast
Ball portrait and English Goal Guard portrait. Automated nonblank/control
checks are not a claim of manual polish review of every screenshot.

## Local iOS Preflight

Isolated checkout: `/tmp/kras-native-preflight-7f270c5`, initially and finally
clean. Source tree: `30c5384cff9628fa8048d7a52945930fd814d86f`.
Export input SHA-256:
`f6040009bb487af0277063c76f9533abb5a5e1d17f3b3c0fb200875e70b87cdd`.

Cold normal import succeeded; strict import guard passed. Newly generated
export: `/tmp/kras-preflight-7f-ios-export`.
Actual local toolchain: `/Applications/Xcode-27.app/Contents/Developer`,
Xcode 27.0 (27A266a), iphoneos SDK 27.0 (24A430).
`tools/export_ios.sh device` exited zero with BUILD SUCCEEDED.
Source/output evidence was recorded and independently verified successfully.

Actual app:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.ipK95yaOPT/Build/Products/Release-iphoneos/KrasPass.app`.
Read from its Info.plist: com.shary.kraspass, 1.1.11 (110).
Arm64 Release-iphoneos binary, 185 MB, minimum iOS 15.0.
Pack in app and newly exported pack share SHA-256:
`9da5fc8d2f5a6e8e844d064933cca1031487503a1411c714fcf9d0df14e1d4c1`.

The Apple bridge library was reused from the preceding local preflight, not
rebuilt. Its sources/build script have no diff between the two commits.
Device library SHA-256:
`b8b87ae49b4c87b100bd8a0c72960217c0cd6cf222e21e06fbd6f174f70956ac`.
The game pack and Xcode project were freshly generated, not reused.

Signing was intentionally disabled. `codesign -dv` exited one with
"code object is not signed at all". This is compilation, not an Archive,
Distribution signature, install, upload or App Review submission. No Xcode
Cloud service, P12 import, password request, certificate creation/revocation
or production change occurred.

Saving evidence initially failed with ENOSPC. Only this run's generated
`.godot` cache and Xcode `Build/Intermediates.noindex` were removed, after
all owned processes completed. App, export, source and logs were preserved.
Saving succeeded afterwards; observed free space was 2.4 GiB. Disk headroom
must be rechecked before a signed archive, not assumed sufficient.

Export/import logs retain known iOS-only extension diagnostics from the macOS
editor. The existing dedicated validator reported fatal=[] and clean=false.
These logs must not be described as error-free. The normal cold import and
Xcode compilation did succeed independently.

## Additional Scope Checks And Gates

All 27 files across six natural-environment source-manifest entries match
their declared MD5 checksums. The catalogue declares CC0-1.0 and retains
provider URLs. This check is not ownership certification of every asset.
Runtime asset/data/script text scan found no Crash/Crash Bash character or
asset names; ordinary uses of the word crash in software comments remain.

Inspected glass styling is Godot StyleBoxFlat/color styling in ui_kit.gd.
The update text accurately describes a translucent glass style. Native Apple
Liquid Glass support in game controls has not been verified; do not certify
the earlier Apple-specific request solely from these styles or SDK version.

Current-source all-game balance run 37730069685 and quality/network run
37730081774 remain live, pinned to 7f270c5. Latest observed balance progress:
catalogue and four game jobs passed, none failed; overall queued. This is
partial, not full-campaign success. The source remains unmerged into main.
Game/device polish, all-map/player/controller QA, production synchronization
and positive client connectivity, final signed local archive, upload,
processing and review submission remain unproven and outstanding.
