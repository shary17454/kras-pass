# Native iOS Migration Audit

This document is the Phase 1 baseline for a possible full native iOS rewrite of
Kras Pass.

## Executive Finding

The current repository is not a Flutter application. It is a Godot 4.7 project
with generated iOS export files under `build/ios/`.

That changes the migration scope materially:

- There is no Flutter or Dart runtime dependency to remove.
- The current App Store build is a Godot-based iOS export, not a native SwiftUI
  application.
- A 100% native iOS version would be a full gameplay-engine rewrite in Swift,
  SwiftUI, SpriteKit/SceneKit/Metal, GameController, AVFoundation, and native
  persistence APIs, not a Flutter-to-SwiftUI conversion.

## Source Inventory

Verified project shape:

- Engine: Godot 4.7.1.
- Main scene: `scenes/boot.tscn`.
- Source scripts: 132 `.gd` files.
- Test scripts/scenes: headless compile check and integration suite.
- App Store assets: generated icon set and iPhone/iPad screenshots.
- iOS export: `build/ios/KrasPass.xcodeproj`.
- Runtime content: JSON-driven game data and localization.

Content parity targets:

- Characters: 8.
- Mini-games: 21.
- Arenas: 23.
- Power-ups: 12.
- Adventure worlds: 5.
- Achievements: 42.
- Localization keys: 538 Arabic and 538 English.

## Existing Architecture

The Godot implementation is already modular:

- `src/core`: logging, balance, registry, event bus, scene routing, platform
  services, pooling.
- `src/input`: player, AI, replay, and future network input normalized through
  `InputFrame`.
- `src/match`: match configuration, lifecycle, scoring, tournament and
  adventure sessions.
- `src/minigames`: 21 mini-game controllers.
- `src/ai`: shared AI brain plus specialized mini-game brains.
- `src/replay`: hybrid replay format with inputs and positional keyframes.
- `src/save`, `src/progression`, `src/settings`: local persistence and profile
  state.
- `src/ui`: screen routing, widgets, HUD, menus, settings, stats, achievements,
  replay screens.

## Native Target Architecture

If the project is rewritten natively, the equivalent iOS structure should be:

```text
KrasPass/
  App/
    KrasPassApp.swift
    AppEnvironment.swift
  Core/
    Logger/
    Registry/
    Balance/
    EventBus/
    SceneRouter/
  Gameplay/
    Match/
    MiniGames/
    Actors/
    Arenas/
    PowerUps/
    AI/
    Replay/
  Input/
    InputFrame.swift
    GameControllerInputSource.swift
    TouchInputSource.swift
    AIInputSource.swift
    ReplayInputSource.swift
  Persistence/
    SaveStore.swift
    SettingsStore.swift
    ProgressionStore.swift
  Presentation/
    Views/
    ViewModels/
    Components/
    HUD/
  Resources/
    Data/
    Localization/
    Assets.xcassets
  Platform/
    Audio/
    Haptics/
    Privacy/
    AppLifecycle/
Tests/
  Unit/
  Integration/
  UITests/
```

Recommended native APIs:

- SwiftUI for menus, HUD, settings, profile, achievements, results, replay
  library, and App Store-facing screens.
- SpriteKit or SceneKit for real-time gameplay rendering and physics. SwiftUI
  alone is not appropriate for 21 physics-based mini-games.
- GameController for physical controllers.
- Swift Codable for existing JSON content.
- SwiftData or file-backed Codable persistence for local profile data. Current
  behavior is local-first and does not require CloudKit.
- AVFoundation plus native haptics for audio and feedback.
- OSLog `Logger` for structured logs.

## Phase 1 Verification

Commands run:

```bash
env HOME=/tmp/kras-pass-home godot --headless --path . --import
env HOME=/tmp/kras-pass-home godot --headless --log-file /tmp/kras-pass-compile-native-audit.log --path . tests/compile_check.tscn
env HOME=/tmp/kras-pass-home godot --headless --fixed-fps 60 --log-file /tmp/kras-pass-tests-native-audit.log --path . tests/test_runner.tscn
```

Results:

- Compile check: passed, 133 scripts compile.
- Test suite: passed, 837 assertions.
- Fixed during this phase: empty replay keyframes no longer call
  `Marshalls.raw_to_base64`, removing replay serialization errors from the
  passing test log.
- Remaining engine-level log noise: macOS CA certificate retrieval warning and
  Godot resource leak messages at process exit.
- iOS Release build without signing: passed with `CODE_SIGNING_ALLOWED=NO`.
- Remaining Xcode warning: AppIntents metadata extraction is skipped because
  the generated Godot project has a Swift stub but no AppIntents dependency.

## App Store Compliance Notes

The iOS export previously contained Camera, Microphone, and Photo Library usage
descriptions even though the app does not use those permissions. Those keys
should not be present unless the app truly accesses those APIs.

Fixed during this phase:

- Removed unused Camera usage description from the iOS export preset and
  generated Info.plist.
- Removed unused Microphone usage description from the iOS export preset and
  generated Info.plist.
- Removed unused Photo Library usage description from the iOS export preset and
  generated Info.plist.
- Removed duplicated generated iOS files whose filenames ended in ` 2`.

Current required privacy posture:

- Tracking: disabled.
- IDFA: not used.
- Non-exempt encryption: false.
- Data collection: none declared.
- Permissions: no camera, microphone, photo library, location, contacts, or
  notification permissions required by current functionality.

## Migration Risk

A full native rewrite is high risk because the existing app is not a simple
form-based product. It contains real-time physics, AI, procedural geometry,
replays, generated audio, multi-input routing, and 21 separate game rule sets.

The safe migration path is incremental:

1. Freeze the Godot version as the behavioral oracle.
2. Port shared data models and JSON validation to Swift.
3. Build native shell and menu flows in SwiftUI.
4. Port one simple mini-game end to end.
5. Build a native deterministic test harness.
6. Port remaining mini-games by category.
7. Verify iPhone/iPad, RTL, accessibility, performance, and App Store metadata.
8. Remove Godot only after feature parity is proven.

## Phase 1 Status

Phase 1 is partially complete:

- Codebase reviewed at the project, data, docs, test, and iOS export level.
- Flutter/Dart absence verified.
- Existing Godot architecture mapped.
- Native architecture direction documented.
- Baseline tests established.

Phase 1 is not fully complete for a production native rewrite because a
screen-by-screen and mini-game-by-mini-game parity specification still needs to
be authored before Swift implementation begins.
