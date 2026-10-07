# Courier Cargo Reaction Qualification

Repository: shary17454/kras-pass; remote: origin (Git SSH).
Branch: fix/kras-courier-cargo-reaction; parent: fix/kras-podium-results-layout.
Tested runtime commit: 333c237159e2c3ec4583fc433b910c2145811f69.
The frozen tracked working tree tested below was committed unchanged as this commit.
No main merge or production deployment was performed.

## Change

Star Rush and Crate Relay display carried cargo publicly in their HUD.
Courier AI previously reacted to the live count immediately when choosing a
rival. It now selects using bounded, delayed observations, sampled by the
existing perception clock. Hidden rivals lose observation credit; reappearance,
round restart and reconfiguration require fresh observations. Own inventory,
delivery capacity, banking logic, human movement and network protocol are unchanged.

## Current Evidence

- Focused pickup/cargo suite: 406 assertions passed in 1.6 seconds, exit 0;
  strict test guard passed. Covers all four difficulty tiers, first acquisition,
  changing counts, regular sampling, hidden/reappearing rivals, target selection,
  restart/reconfiguration, bounded history and zero-delay diagnostics.
- Full gate: 411 scripts compile; 504 resources, 22 autoloads, 27 routes,
  eight characters and zero structural inventory issues.
- Full units/integration: 385043 assertions passed in 545.8 seconds.
- Three-lap race and six boss regression stages passed; every stage passed
  the script's strict log guard. Whole check_party.sh command exited 0.
- Stability: one cycle of 39 matches, zero failures; mesh/material/texture
  caches and cached audio PCM released to zero. Settled memory: 140042024 bytes.
- Server: 204 passed, zero failed/cancelled/skipped, exit 0; all six world
  fixtures came from this current Godot test run, not a parent run.
- Locked server dependency install used --ignore-scripts. npm audit reported
  zero known vulnerabilities; this is not an application-security certification.
- git diff --check passed before the runtime commit.

Evidence: /tmp/kras-courier-cargo-isolated.log;
/tmp/kras-courier-cargo-full.log;
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.07sgAQ;
/tmp/kras-courier-cargo-server-local.log.

Initial focused invocation lacked an isolated writable save directory and emitted
save-write errors; the isolated rerun replaced it as acceptance evidence.
Initial server invocation lacked jose/ws; npm ci restored the locked dependencies.
The next sandboxed server run could not bind localhost (EPERM); the local-session
rerun above passed. Preserve /tmp/kras-courier-cargo-tests.log,
/tmp/kras-courier-cargo-server.log and
/tmp/kras-courier-cargo-server-qualified.log as diagnostic evidence.
The macOS system-CA diagnostic and intentional negative-test/memory-warning
fixtures remain in logs; no new GDScript runtime error was accepted.

## Release Gates Remain Open

Live ASC inspection confirmed app 6801506973 / com.shary.kraspass,
published 1.1.10 and latest upload 1.1.10(107). Reading the entire upload list
through the disappearance of See More confirmed highest used build 108.
No version/build metadata, upload or review submission was changed.

Local Keychain contains Apple Distribution: Shary ALADHYANI (4HM66AD594),
fingerprint C81811A21B592B030D57CD5B180227BDDADEA4C1. No P12 import/password,
new certificate or revocation occurred. Global xcode-select currently points to
CommandLineTools; explicit DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer
verified Xcode 27.0 (27A266a) and iPhoneOS SDK 27.0 without changing global settings.
This is not a signed Archive or signature verification for this source.

Railway /health currently reports ok=true, authentication_ready=true,
multiplayer_enabled=false. No protected account export or database change occurred.

Campaign 37577604329 remains live on immutable c5fa1f9, not this courier source.
Seven game jobs succeeded at the last poll; storm_heart was running. Do not
relabel that campaign or the prior iOS exports as qualification of this commit.
Natural balance of these two delivery games must be repeated on the final source.
Remaining broad gates include full current-source gameplay/perception/polish QA,
four-human vehicle readability, physical iPhone/iPad performance/thermal/battery,
production backup/restore and coordinated online protocol rollout, approved source
promotion, new committed Version/Build, local Distribution Archive and actual
signature checks, processed upload, correct build selection and review-state proof.
One stability cycle does not establish long-session leak or device performance safety.
