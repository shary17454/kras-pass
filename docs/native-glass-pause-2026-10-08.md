# Native Glass Pause Qualification

Worktree: `/private/tmp/kras-crate-swing-arbitration`.
Branch: `feature/kras-online-random-rotation`.
Parent: `1c52aae9abcac5a963c75ce5072e3b7a08a7f469`.
This document qualifies the working-tree addition, not an App Store archive.

## Implementation

The Apple bridge presents a UIKit pause menu using UIGlassEffect and native
glass button configurations on iOS 26 and later. Unsupported platforms and
old bridge binaries retain the existing Godot menu. Native presentation does
not move simulation, pause state or network authority into UIKit.

The menu has localized resume, restart, settings and quit actions, RTL,
scrolling within the safe area, keyboard/controller navigation, a native
restart confirmation and reduced-transparency/motion handling at presentation.
Online restart is disabled and opening a local menu does not pause peers.
Callbacks carry a presentation generation; dismissed and obsolete callbacks
cannot mutate another match. Match teardown disconnects native callbacks.

## Verified Locally

- Godot 4.7.1: all 427 scripts compile.
  `/tmp/kras-glass-current-compile.log`; strict log check passed.
- Presenter unit and real match-scene integration: 48 assertions passed.
  `/tmp/kras-native-glass-flow-rerun.log`; strict log check passed.
  The first run failed because its online fixture had no match data. The
  fixture now provides/restores a transport and match data and asserts that
  setup really created a non-aborted match before testing the menu.
- Local Xcode 27 built the current native sources successfully for device
  arm64 and simulator arm64/x86_64, producing KrasApple.xcframework.
  `/tmp/kras-native-glass-bridge-final.stdout`.
- `git diff --check` passed.
- Full current-source suite: 392405 assertions passed in 359.6 seconds,
  exit 0; strict test log check passed.
  `/tmp/kras-glass-current-all-tests.stdout`.

## Pending Gates

Expected failure-injection log messages were traced to the deliberate test
harness, save-write and router-recovery fixtures. The actual full-suite
terminal summary and strict log validation both passed.

Actual native UI visual and interaction QA remains required on iPhone/iPad,
both orientations, large text, VoiceOver, and controller restart confirmation.
The Mac was locked when browser access was attempted. No physical device app
was installed, no certificate was changed and no P12 was imported.

The external all-game balance campaign 37754749544 uses the parent commit,
not this changed source. Its partial results cannot qualify this addition.
Existing independent sweeper character and ring spawn warnings remain open.
Production online enablement, current-source release acceptance, signed local
Xcode Archive, upload, processing and review submission remain separate gates.
None of those release steps was performed here.
