# Current local signed archive qualification

Archive source: 3863e7c8a340c95cab6398ffe8e97f4e165d0ec9, tree
eb03513b176e923e5681abdd4d6635d8fa197529, published feature branch
feature/kras-online-random-rotation in shary17454/kras-pass.
Detached checkout: /tmp/kras-native-3863e7c-current.
Release-input SHA256: 02d11343b71b54cb13a97e33f6968504eba62c5693aa994181b09e09ace2661e.
Export record/verify passed before archive and verify passed afterward.
Generated untracked test UID files are excluded by tests/* in the iOS preset;
no tracked release input changed. The authoritative working checkout stayed clean.

## Separate verified results

- Local Xcode 27.0, build 27A266a, iPhoneOS SDK 27.0 (24A430).
  Active global xcode-select points to CommandLineTools. DEVELOPER_DIR selected
  /Applications/Xcode-27.app/Contents/Developer for these commands only.
- Fresh Godot iOS export: /tmp/kras-3863e7c-ios-export.
  Apple bridge reused after confirming native/apple and its build script have
  no changes since the previous qualified source; device library SHA256
  24100d25fd982f76552c008e1783f73fc27d62d64d7b3219a0ef10bc3a5b9077.
- Release generic/platform=iOS archive exited 0, ARCHIVE SUCCEEDED:
  /tmp/KrasPass-3863e7c-1.1.11-110-qualification.xcarchive.
- Actual archived app plist: com.shary.kraspass, Version 1.1.11, Build 110.
- Strict deep codesign verification passed. Actual Authority:
  Apple Distribution: Shary ALADHYANI (4HM66AD594), TeamIdentifier 4HM66AD594.
- Embedded App Store profile UUID 91bc3a38-3753-4ed6-9f8b-a26974ff9d5e matches
  team, bundle, installed certificate and get-task-allow=false; expiry
  2027-09-19 17:59:00 UTC. No P12 import/password, new/revoked certificate or Cloud.
- Export and archived PCK SHA256 both
  1b974b99ed63c07cccd44e6c7794f604fee98727e653d6d7b9c20b57f31bf0de.
- Executable and dSYM arm64 UUID both B66407B6-B081-333A-B761-E88F56D5BECA.

Evidence: ../qualification-native-3863e7c-2026-10-09/ contains archive log,
source/export attestation, import/export logs and codesign logs. Source and
archive also remain at their absolute /tmp paths above.

## Open gates

The iOS-only extension emits known macOS-editor diagnostics during export;
checker reports fatal=[] and clean=false. They remain in raw logs. This is not
an error-free runtime qualification. Compilation and signing do not prove
iPhone/iPad performance, thermal/battery behavior, controls or production auth.
The earlier be4d4c1 archive does not contain this source; this new archive does.

This is a qualification archive, not a final release acceptance. Current
App Store Connect build availability was not reread this turn. Numbers must
be freshly checked before any upload. No IPA export, Apple distribution
validation, upload, processing or submission occurred. All-game natural balance,
device acceptance, Railway database backup/restore authorization, migration,
production connection and final source approval remain open. No main merge.
