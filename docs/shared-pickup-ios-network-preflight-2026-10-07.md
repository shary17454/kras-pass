# Current iOS and Network Preflight

## Source Boundary

Repository: shary17454/kras-pass; remote: origin (SSH).
Branch: fix/kras-shared-pickup-observation.
Source inspected and exported: 679700ecdad1f6fc826f063aa3cb5e28775f0e97.
Tree: 32f2532811e7e5fc225eff45b18a2f70aa0c4990.
Release-input SHA256:
5957981f12e216383dd43eeff1b366549d6d19bd507f6e6ddc43701f0855a614.

The runtime/test commit remains c5fa1f9813478ed8ab3a6ef26033e93b57b65928;
679700e adds documentation only. Gameplay remains frozen for the existing
all-39 campaign. This report does not promote source to main or certify
the full release scope. Export generated 13 untracked test .gd.uid files;
they are preserved, not silently staged or removed.

## Local Xcode 27

Local Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430).
Godot 4.7.1; godot-cpp pin 714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa.

The first native bridge build failed because sandboxed clang could not
create temporary files. Retained log:
/tmp/kras-shared-pickup-xcode27-bridge.log.
The same build succeeded in the approved local execution environment,
including device and universal-simulator libraries and XCFramework creation.
Successful log: /tmp/kras-shared-pickup-xcode27-bridge-local.log.
No P12 import, password request or certificate modification occurred.

Fresh project export and unsigned device Release compilation completed
with exit 0 through tools/export_ios.sh device. Evidence:

- /tmp/kras-shared-pickup-ios27-build.log
- /tmp/kras-shared-pickup-ios27-evidence
- /tmp/kras-shared-pickup-ios27-export/.kras-source-export.json
- /tmp/kras-shared-pickup-ios27-before.json

Source-before/source-after identity matched; record and verify commands
both exited 0. The export stamp covers generated output hashes, not just
an inferred source label. Before any later reuse, verify against the
recorded source checkout; a subsequent documentation commit changes HEAD
even when gameplay is unchanged.

Actual built application:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.pCnVSDpQP3/Build/Products/Release-iphoneos/KrasPass.app.
Its Info.plist reads com.shary.kraspass, Version 1.1.10, Build 107.
It is arm64, about 183 MB, minimum iOS 15, iPhone/iPad, with both landscape
orientations declared. codesign --verify --deep --strict returned exit 1,
"code object is not signed at all", as expected for this unsigned QA build.
This is NOT an Archive, a signed distribution build, a phone performance
test or an upload. Xcode Cloud was not used.

## Signing Profile Preflight

Fresh structured decoding confirmed profile
91bc3a38-3753-4ed6-9f8b-a26974ff9d5e,
"Kras Pass App Store Xcode 27 2026-09-20":

- Application identifier: 4HM66AD594.com.shary.kraspass.
- Team: 4HM66AD594.
- Certificate SHA1: C81811A21B592B030D57CD5B180227BDDADEA4C1.
- Expiration: 2027-09-19 17:59 UTC.
- Sign in with Apple: Default; get-task-allow: false; no device list.

This matches the installed Apple Distribution identity verified in the
preceding local preflight. Profile compatibility is not proof of a signed
Archive; actual archive entitlements and embedded profile still need checks.

## App Store Connect Inventory

Authenticated Chrome UI was inspected, not inferred from earlier reports.
Correct application: Kras Pass, Apple app ID 6801506973.
Distribution shows Version 1.1.10, Build 107, Ready for Distribution.
TestFlight Build Uploads shows 1.1.10 (107), Complete, Sep 28, 2026;
also an older 1.1.8 (108), Complete, Sep 14, 2026.
Therefore 108 is already used; do not reuse it as the next build merely
because the latest release build is 107. Recheck the full inventory before
allocating a new build and use a new app version for the release update.
No pending replacement release is visible on this distribution page.
No release cancellation, metadata mutation, upload or submission occurred.

## Four-Process Network Check

Command: GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js
--game=gem_grab --humans=4 --seed=1209001.
Exit 0; four actual Godot clients and a real local WebSocket service.
All agreed on scores [4,10,12,1]; collection and movement checks passed.
Host ID 1 and guest ID 2 reconnected. Guest world snapshots: 927, 908, 927.
Maximum recorded server-loop delay: 54 ms; no phone latency claim follows.
Log: /tmp/kras-shared-pickup-network.log.
Peer evidence:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-U07C20.

This uses scripted inputs and the network fixture's shortened round, not
four physical humans, natural balance qualification, production Railway,
authenticated Internet play or deterministic replay certification.

## Outstanding Release Gates

Campaign 37577604329 is still live on immutable runtime c5fa1f9, seed offset
1200000. Latest checked status: queued, two successful jobs, 38 pending,
no failed jobs. Do not dispatch a duplicate or certify all 39 from this
partial result. Handle:
https://github.com/shary17454/kras-pass/actions/runs/37577604329.

The full goal remains incomplete: all-game balance/perception/polish;
physical iPhone/iPad gameplay, orientation, sustained FPS/battery/thermal;
approved source promotion and protected production backup/restore;
coordinated Railway protocol rollout, API/auth/Internet acceptance;
new Version/Build committed to the approved remote; exact-source local
Distribution Archive and signature validation; upload, processing and
separately verified App Review submission. No old build is presented as
containing these newer fixes.
