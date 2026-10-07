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

## Follow-Up: Partial Natural Campaign and Rendered QA

Same immutable campaign 37577604329: catalogue, tank_arena and crumble_court
completed successfully; ring_rumble was in progress and the remaining jobs
queued. Downloaded reports are retained under
/tmp/kras-c5fa1f9-campaign-partial. Each report's checkout.txt and source.json
identify c5fa1f9813478ed8ab3a6ef26033e93b57b65928 and seed offset 1200000.
All six downloaded import/policy/simulation logs passed the corresponding
strict local log guards. Each game completed 24 baseline, 16 matched-seed
same-character difficulty comparisons, and both mutator/chaos checks.

| Game | Average Seconds | Expert Share | Slot Bias | Character Bias | Ties |
| --- | ---: | ---: | ---: | ---: | ---: |
| tank_arena | 102.3042 | 0.54658 | 0.08333 | 0.08333 | 0 |
| crumble_court | 13.7361 | 0.56875 | 0.15 | 0.155 | 1/24 |

Both report flags arrays are empty. This is not a universal balance claim:
crumble_court's raw slot wins are [9,5,10,1], including a tied winner, and
its approximately 14-second average warrants party-flow review against
the desired 30-second-to-three-minute typical rounds. The small sample
must not be used to justify changing character stats or spawning rules
without further diagnosis. No threshold or runtime code was changed.

Rendered tests/party_visual_check.tscn completed locally with exit 0,
PARTY VISUAL CHECK: 0 failures and strict runtime log guard exit 0.
Arabic/English, 1280x720 landscape and 540x960 portrait were exercised:
eight menu routes, save-compatibility warnings, standings/podium, and
four-touch setups for ring_rumble, tank_arena and sabaq_sawarikh.
Isolated save root: /tmp/kras-shared-pickup-party-visual-save.
Logs: /tmp/kras-shared-pickup-party-visual.stdout and .log.

Visual inspection went beyond the geometric assertions:

- /tmp/kras-party-landscape-ar-podium.png: the standings scroll region
  below the podium is too short to show a complete first row at once.
- /tmp/kras-party-portrait-ar-podium.png: the first row fits but subsequent
  ranks require scrolling in a narrow area above the action buttons.
- /tmp/kras-party-portrait-four-touch-tank_arena.png: players are contained
  in the world area, but the vehicles are very small with four shared touch
  regions. This needs gameplay/readability acceptance, not only bounds checks.

The test proves rendered nonblank layouts and its explicit bounds checks;
it does not prove every minigame/orientation, four human touch usability,
safe-area behavior on real iPhone/iPad, sustained FPS or thermal/battery.
These polish findings remain open while gameplay source is frozen.

Fresh production probes: GET /health returned ok=true,
authentication_ready=true, multiplayer_enabled=false. GET /account without
credentials returned 401, error=sign_in_again, Cache-Control=no-store and
no Access-Control-Allow-Origin header. No production account was read,
backup exported, secret changed or deployment performed. Server health
and unauthorized rejection do not qualify signed-device Apple login or
production online gameplay.

## Follow-Up: Simulator Build Versus Simulator Execution

Source 8a7f262 was freshly exported for simulator using local Xcode 27.
Release compilation succeeded (exit 0) and source/output record and verify
both exited 0. Build log:
/tmp/kras-shared-pickup-ios27-simulator-build.log.
Stamp: /tmp/kras-shared-pickup-ios27-simulator-export/.kras-source-export.json.
Built app:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.iBzSnKRVGX/Build/Products/Release-iphonesimulator/KrasPass.app.

Actual engine simulator library and app architecture: x86_64 only, confirmed
with lipo/file. The supplied Godot engine template lacks an arm64 simulator
slice. This does not imply the arm64 device build is invalid.

A new isolated iPhone16ProMax simulator was created on installed iOS26.5:
06EE9294-49FF-454E-8325-9CA0BF4D3A96. Its arm64 boot completed, but a later
boot request with --arch=x86_64 returned code22: supported architecture is
arm64 only. That simulator was shut down; no unrelated simulator was stopped.

Installed iOS18.6 advertises x86_64/arm64 support. A separate QA device,
266481DA-646B-4503-A6A0-1627E9F9A5A7, accepted x86_64 boot, but bootstatus
and installation did not complete. Both owned commands were stopped (exit143)
and that QA simulator was shut down successfully. No automatic restart,
runtime download, certificate change or physical-phone install occurred.
The devices are retained, not deleted. Application launch was NOT achieved;
do not report this as native gameplay acceptance. An arm64 simulator template
or an approved physical-device session remains necessary for native QA.

The same campaign's ring_rumble report subsequently completed: 24 natural
baseline matches, 16 paired difficulty comparisons, both smoke variants,
source/checkouts c5fa1f9, seed offset1200000. Average duration37.3826 seconds,
Expert share0.54375, slot bias0.04167, character bias0.08333, tie rate0 and
flags empty. Artifact: /tmp/kras-c5fa1f9-campaign-ring. This is a third game,
not completion of the 39-game campaign; the specific campaign remains queued
for its other games and must not be duplicated merely because of queue time.
