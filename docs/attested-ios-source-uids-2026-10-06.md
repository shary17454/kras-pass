# Attested Local iOS Source and Full Regression

## UID Correction

Source commit: `be430b979fb41d4d0d3c39c0572f6e346adb7238`, branch
`fix/kras-ios-source-uid-completeness`, based on keeper source
`45340110464e762be05f8d362474bdbbfd86f44c`.
Four real Godot-generated script UID files are now tracked: balance evidence,
network version visual probe, crater route regression and HUD numeric direction
regression. The strict exporter still rejects uncommitted release inputs.
No source-evidence exception was introduced.

Editor import completed with exit 0 and the strict import log guard passed.
Tracked and untracked Git status was empty afterwards. Source inspection passed:

- Tree: `b5bffeb7bfe3de40a1a05cca1e7de82388c372a6`.
- Input SHA256: `370696f46647b7d9360bcec40ba6a3f5df23c12f03884c46dbe14499ee6067fe`.
- Import logs: `/tmp/kras-ios-source-uids-import.{log,stdout}`.
- Source snapshot: `/tmp/kras-ios27-uid-attested-before.json`.

## Local Xcode 27 Export

Xcode 27.0 build 27A266a, iPhoneOS SDK 27.0. The freshly compiled native Apple
framework from the previous source-qualified native check was reused; its
tracked Objective-C++ source is unchanged. No old game PCK was reused.
`tools/export_ios.sh device` completed with exit 0 and `BUILD SUCCEEDED`.

- Checkout: `/tmp/kras-ios-source-uid-completeness` at the source commit above.
- Export: `/tmp/kras-ios27-uid-attested-export`.
- Logs: `/tmp/kras-ios27-uid-attested-evidence`.
- App: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.8AiZkX453A/Build/Products/Release-iphoneos/KrasPass.app`.
- Export and packaged PCK SHA256 both match
  `b2f08c4a16271e23f1e835992c065c0a16a383a3cb99b9517bbd21ffbabe3dee`.

`ios_export_evidence.py record` and `verify` both completed with exit 0 against
the pre-export source snapshot. The export contains
`.kras-source-export.json`, including hashes of the native library, game pack,
engine and generated project. This attestation belongs to `be430b9`, not an
arbitrary later documentation or release commit. A later source cannot silently
reuse this export.

The known iOS-only extension diagnostic remains explicitly non-clean on macOS.
The build is unsigned, still version 1.1.10 build 107, and **not** a new upload
candidate. No Archive, Distribution signature, upload, processing or review
submission was performed.

## Full Gameplay Gate

The parent keeper source was unchanged during the completed full local run:
`tools/check_party.sh`, exit 0. UID additions change no gameplay scripts.

- Compilation: 394 scripts.
- Inventory: 439 resources, 22 autoloads, 27 routes, 8 characters, zero issues.
- Full tests: 366313 assertions passed in 263.3 seconds.
- Race regression and six boss probes passed.
- Stability: one cycle over all 39 games, 39 matches, zero failures.
- Every stage passed its strict log guard.
- Main log: `/tmp/kras-keeper-arrival-full-gate.stdout`.
- Evidence directory: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.0wIcxg`.

All six actual world captures from this run were supplied to `npm test`.
Result: 193 passed, zero failed and zero skipped.
Log: `/tmp/kras-keeper-arrival-server-fixtures.stdout`.
The iOS source-evidence Python suite passed all 12 tests; the export-log Node
suite passed all 4 tests. `npm audit --omit=dev --json` returned zero reported
vulnerabilities; this is a dependency advisory check, not a complete security
assessment.

## Real Local Network Checks

Magnet Court seed 1504242 was checked with separate Godot peers, real local
WebSocket service and protocol 2. Both checks completed with exit 0:

- 2 human processes + 2 bots: movement/reconnect passed; both peers agreed on
  `[21,20,19,21]`; guest received 1088 world snapshots.
- 4 human processes: movement passed, the designated disconnected host/guest
  reconnected, all four agreed on `[20,24,21,22]`.
- Logs: `/tmp/kras-keeper-arrival-network.stdout` and
  `/tmp/kras-keeper-arrival-network-four.stdout`.

Server loop maxima were 39 ms and 100 ms respectively under concurrent tests.
These are diagnostics, not latency or FPS acceptance. Automated human processes
are not four people holding a touchscreen or physical controller tests.

## Outstanding Release Gates

The full GitHub matrix and natural campaign target their recorded source commits;
their pending status is not replaced by these local checks. Broader natural
balance, rendered human QA, physical-device performance/thermal/battery testing,
coordinated production protocol rollout, remaining product acceptance, final
integrated source, new version/build, signed Archive and Apple upload/review
remain outstanding. No main merge or Railway production change occurred.
