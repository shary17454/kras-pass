# Sweeper Exact-Source Qualification

Tested source: dd775f94787137b4a951039c881340b95453bd90.
Tree: 5383a268882f116c3fc1399e2f5ed74383360213.
Branch: fix/kras-sweeper-relative-arrival. Repository: shary17454/kras-pass.
This report and generated test UIDs are later bookkeeping, not a new tested
release commit. No main merge, production change or Apple submission occurred.

## Full Regression

`sh tools/check_party.sh` exited 0. All 398 scripts compiled; inventory
contained 491 resources, 22 autoloads, 27 routes, eight characters and zero
structural issues. All 371697 assertions passed in 300.3 seconds. The actual
three-lap race and six boss probes passed. One stability cycle completed
39 games with zero failures and released cached materials, meshes and textures.
Settled memory was 133188002 bytes. The deliberate memory-warning fixture is
not a spontaneous memory fault; this cycle does not prove long-term leak,
phone FPS, thermal or battery acceptance.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.Hi1kW8`.

All six server world-fixture environment variables used the fresh files in
that run's `saves-tests` directory. `npm test` exited 0: 204 passed, zero
failures, cancellations or skips, 1353.4 ms. Log:
`/tmp/kras-sweeper-qualified-server.log`.

## Real Local Network Processes

`GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js
--game=sweeper_storm --seed=909001` exited 0. Two human-input processes plus
two bots, then four human-input processes, passed. The scripted host and
guest reconnect paths passed; peers agreed on [4,8,12,16]. Guest world
snapshots in the four-process run were 728, 709 and 728. Maximum reported
server event-loop delay was 49 ms.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-sUTIg2`.
These are scripted local WebSocket fixtures, not four physical people,
production Internet acceptance, natural balance rounds or deterministic replay
proof. Natural difficulty evidence and remaining flags are retained in
`sweeper-relative-arrival-2026-10-07.md`.

## Fresh Local Xcode 27 Build

Explicit DEVELOPER_DIR selected `/Applications/Xcode-27.app/Contents/Developer`:
Xcode 27.0 (27A266a), iPhoneOS SDK 27.0 (24A430). A fresh Godot export and
unsigned Release device build succeeded. No Xcode Cloud build was started.

Export: `/tmp/kras-ios27-sweeper-qualified-export`.
Logs: `/tmp/kras-ios27-sweeper-qualified-evidence`.
Application:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.pdJyLdxpUt/Build/Products/Release-iphoneos/KrasPass.app`.

The source attestation record and verify commands both exited 0 before this
report was committed. Input SHA256:
`c41c6c718f9bcf5aefdb63b6d15b8b02aa2e6add4d8ac99b815ebc924b00793d`.
Exported and built PCK hashes both were:
`aa2edfafcdf8f6cd92ea2b73c17574353f195c86194997753097ef3248543010`.
The build did not reuse an old gameplay PCK.

Only the unchanged native bridge was reused from the previously attested
4989c09cefa7e7c2788908eb96f12dc009aedfba export. Git diff of native/apple and
its build script against that source was empty. Cached device library hash:
`687c3e04947da83e44e0039f63c271402f1f139f1e2c3cb7c385b313b0e23749`;
simulator library hash:
`96942d85006549ad3be4c2295ce573065d40da56d7550c692fac7ffa3b9240a6`.
These matched the earlier native evidence; no native rebuild is claimed.

Built Info.plist: com.shary.kraspass, version 1.1.10, build 107, minimum
iOS 15.0, iPhone/iPad families, portrait and both landscapes. arm64 binary
records SDK 27.0. No camera, microphone or photo-library usage descriptions.
Known iOS-only extension diagnostics during macOS import/export were retained
by the log checker, with no other fatal diagnostics; these are NOT clean logs.

Signing was explicitly disabled. `codesign -dv --verbose=4` returned exit 1
and "code object is not signed at all", as expected. This is compilation,
not a Distribution Archive or signature validation. Old 1.1.10 (107) numbers
are QA-only; do not upload this as a new update. Any final source/number change
requires a fresh attestation, checks and signed archive.

## Remaining Gates

ASC apps navigation returned to login with authResult=FAILED despite an old
account-menu render. No working current inventory, new build number, upload,
processing or review submission is verified. The existing all-39 CI campaign
37549144464 has begun a simulation job, with others queued; its immutable
source is 3c4bbdb6d7437803cd53bba3e721b872ebb4675f, not this later AI change.
No campaign completion or balance clearance is claimed.

Physical device gameplay/performance, current broad balance and polish,
source promotion, approved database backup/restore and migration, coordinated
production network protocol rollout, API/native auth/Internet acceptance,
fresh ASC inventory and version/build, local Distribution Archive and verified
signature, upload/processing and separate App Review submission remain open.
