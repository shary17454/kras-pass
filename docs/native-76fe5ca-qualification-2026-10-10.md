# Current Local Xcode 27 Archive

## Source

Repository: `shary17454/kras-pass`, origin HTTPS.
Branch: `feature/kras-online-random-rotation`.
Archive source: `76fe5ca126db1adf688478713827dc79370544f8`.
Isolated checkout: `/tmp/kras-native-84b7472-current` (detached at the source above).

The first export from 84b7472 completed, but source attestation rejected two
newly generated arena script UID sidecars. Both were committed before a fresh
export. No user work was removed. Generated test UID sidecars are not release
inputs. The native bridge was reused after an empty native/apple and bridge
build-script diff from the previously qualified bc46d4e source; it was not
newly compiled. Its godot-cpp checkout remains pinned to
`714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`.

Fresh export: `/tmp/kras-76fe5ca-ios-export`.
Source attestation record and verification passed before archive; verification
also passed afterward. Export logs retain known iOS-only extension diagnostics
from the macOS editor: fatal=[], clean=false. They are not error-free logs.

## Build And Signing

- Xcode 27.0, build 27A266a, SDK 27.0 (24A430), explicit DEVELOPER_DIR.
- Installed Distribution identity, team 4HM66AD594; no P12 import, password,
  new certificate, revocation, or global Xcode selection change.
- Manual signing profile UUID 91bc3a38-3753-4ed6-9f8b-a26974ff9d5e matches
  bundle, team and installed certificate; expiry 2027-09-19, get-task-allow=false.
- Archive exit 0, ARCHIVE SUCCEEDED:
  `/tmp/KrasPass-76fe5ca-1.1.11-110-qualification.xcarchive`.
- Actual app plist: com.shary.kraspass, version 1.1.11, build 110.
- Local deep/strict codesign verification exits 0; Authority is
  Apple Distribution: Shary ALADHYANI (4HM66AD594), TeamIdentifier 4HM66AD594.
- Embedded profile independently matches. Privacy manifest exists; unneeded
  camera, microphone, photo, location and contacts usage descriptions are absent.
- Portrait/landscape declarations exist for iPhone/iPad; not device layout QA.
- Export and archived PCK SHA256 both:
  c72095c815e1fe9b97ced0a1040c22ecb9c922e2bc6f3074c8f66cfafc26c01c.
- arm64 executable and dSYM UUID both B66407B6-B081-333A-B761-E88F56D5BECA.

## External State And Open Gates

Live authenticated App Store Connect inspection showed Kras Pass app 6801506973.
Newest visible upload: 1.1.10 (107), Complete; TestFlight status Ready to Submit.
1.1.11 (110) was not among the newest visible uploads. This is not an exhaustive
historical build-number guarantee; refresh before an actual upload.

Core run 38020374703 remains in progress on ba3f9f8. Balance run 38018326003 is
nonterminal on older 15279bf; 29 successful completed jobs were visible, including
non-simulation jobs. Neither observation proves all current games READY.

No IPA export, Apple upload, processing or review submission occurred here.
No main merge or Railway production mutation. Device/controller/thermal/battery
QA, current balance acceptance, production backup/restore authorization and
migrations/connectivity, and unfinished product requirements remain open.

Evidence: `/tmp/kras-76fe5ca-source-before.json`, export attestation inside the
fresh export, `/tmp/kras-76fe5ca-ios-logs`, `/tmp/kras-76fe5ca-export.stdout`,
`/tmp/kras-76fe5ca-archive.stdout`, `/tmp/kras-76fe5ca-codesign-verify.log`.
