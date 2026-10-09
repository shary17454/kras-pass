# Local Archive Including Save Backup Fix

Verified published source: 452f92f84e30f7b26bfebc92b2598f124316a56f, tree
fdaca1f4fc5748bc7c57eff91506dc7402adf568 on feature/kras-online-random-rotation
in shary17454/kras-pass. Isolated checkout: /tmp/kras-native-452f92f-current.
Release input SHA256:
e80052556335d873f152c93cf98941c9e9e03e411b8f31c6dcc48c99bb621203.
Source attestation recorded and verified before archive and verified afterward.

Local login.keychain-db contained the requested Apple Distribution identity.
Xcode 27.0 build 27A266a selected using per-command DEVELOPER_DIR; SDK 27.0
(24A430). No global toolchain switch, Cloud build, P12 import/password,
certificate creation or revocation.

Reused the prior Apple bridge only after an empty source/build-script diff
since 3863e7c. Fresh Godot export: /tmp/kras-452f92f-ios-export. Export retains
known iOS-only macOS editor extension diagnostics: fatal=[] but clean=false.
These logs are preserved and are not claimed error-free.

Actual Release iphoneos settings matched bundle com.shary.kraspass, team
4HM66AD594, manual Distribution identity and matching App Store profile.
Archive exited 0, ARCHIVE SUCCEEDED:
/tmp/KrasPass-452f92f-1.1.11-110-qualification.xcarchive.

Actual archived app plist: com.shary.kraspass / 1.1.11 / 110.
Strict deep codesign verification exited 0. Authority is Apple Distribution:
Shary ALADHYANI (4HM66AD594), TeamIdentifier 4HM66AD594. Embedded profile UUID
91bc3a38-3753-4ed6-9f8b-a26974ff9d5e matches bundle, team and installed
certificate; get-task-allow=false, expiry 2027-09-19 17:59:00 UTC.
Export/archive PCK SHA256 both:
bbf3e4a6ef99ba5b29799b855ff4c3c678bba83fd61bc4ea8474aeb4a38de747.
Executable/dSYM arm64 UUID both B66407B6-B081-333A-B761-E88F56D5BECA.
GDScript changes reside in the PCK; unchanged engine UUID is not source proof.

Fresh read-only TestFlight inspection for app 6801506973 before archiving:
latest version shown 1.1.10 (107), Ready to Submit, upload Complete Sep 28.
Upload table also shows older 1.1.8 (108); latest date is not max build number.
No 1.1.11 (110) appeared in the current versions/recent uploads. This is a
point-in-time observation; recheck before any actual upload.

Evidence: ../qualification-native-452f92f-2026-10-09/ contains source/export
attestation, settings, export, archive and codesign logs.

New balance run 37961516661 captured exact source 452f92f, seed offset 9200000,
fingerprint 274d1649bf08d310aab79374014795d542e687e47d2680975398598187ad1774.
It remains incomplete. Network run 37950626662 remains live on older b5e4f9e;
it was not cancelled/replaced. New source network/Core evidence remains needed.

This is a qualification archive, not final product acceptance or an upload.
No IPA/distribution validation, upload, processing or submission. Balance
review, content polish, device/controller/thermal/battery acceptance and
production backup/restore authorization, migrations and actual connection
remain separate open gates. No main merge or production mutation.
