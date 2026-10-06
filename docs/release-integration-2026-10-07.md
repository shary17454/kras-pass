# Unified Development Release Source

## Source and Scope

Repository `shary17454/kras-pass`, remote `origin` (Git SSH).
Branch `feature/kras-release-integration-2026-10-07`.
Integrated code commit: `186a450b1f93c40fb541d980942f56aafb5f596f`.
This report is added after that commit without further code changes.

Read-only remote inspection confirmed main remains
`062a40992b92958573e28e19d8c8c1840560797a`.
There was NO merge to main and NO production deployment.

The integration branch retains the full d1a5a31 development ancestry and includes:

| Work | Source commit | Review |
| --- | --- | --- |
| Arabic/English privacy policy | d53cd78bad4ecd68705428ffc30c8302ba8d2adc | PR 134 |
| Versioned account schema and rollback checks | 59f4a134a0a5e53bee8c7e5d2f1126f591ba6244 | PR 135 |
| Original prebaked SFX/ambience | 08362dc7f9d60c945d53bb4e0ce2c40b97171119 | PR 136 |
| Symmetric equal kart contact damage | dc2477cb46acc4ebad9eee3b5675b275b1fb4374 | PR 137 |
| Seeded nearest-rival target ties | a9189108e7ba94cc03e2b82f4dae519eb52d5849 | PR 138 |

All three sibling merges completed without conflicts. No imported P12, new
certificate, revoked certificate, production account copy, changed secrets or
online enablement occurred. This is a unified development source, NOT a release
candidate accepted for App Store upload.

## Checks on Integrated Code 186a450

- All 396 Godot scripts compile; `/tmp/kras-integrated-compile.log`.
- Systems suite: 724 assertions passed; `/tmp/kras-integrated-systems.log`.
- Both Godot log guards and git diff whitespace check passed.
- Account/schema tests: 15 passed, zero failures/skips, including version
  preservation, migration rollback, foreign-key/schema rejection, owner binding,
  deletion authorization and Apple-token cryptographic fixtures.
- Full server suite: 204 passed, zero failures/skips. Six real engine captures
  came from the a918910 parent full gate at `kras-party-check.VE3X0u/saves-tests`.
  That parent lacks the new audio bank but has the same match/network schemas;
  these captures are NOT labeled as integrated-code engine captures.

The memory-warning message in systems tests is intentionally invoked by the
fixture; it is not evidence of an actual iPhone memory/thermal warning.
Account token fixtures are not a physical-device Sign in with Apple session.

## Current AI Parent Evidence (a918910)

The full Godot gate's tests stage passed 368378 assertions in 365.2 seconds.
Compilation: 395 scripts. Inventory: 447 resources, 22 autoloads, 27 routes,
8 characters, zero issues. Real race regression and six configured boss fights
passed. The full gate then completed with exit code zero and 39 stability
matches with zero failures. Every stage passed its strict Godot log guard.
This is one stability cycle, not a long soak or proof of absent memory leaks.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.VE3X0u`.
This parent full gate is NOT a full gate for integrated code 186a450.

Four actual Godot client processes with a real local WebSocket server completed
Scrap Karts with matching scores `[20,16,14,10]`. Guest and host reconnection
passed; guests received 1689/1708/1708 world snapshots. Maximum observed server
event-loop delay was 71 ms. Evidence: `kras-network-smoke-1AhaPN` in the same
temporary-directory root. This is not Internet, four physical humans, all-game
network qualification or device FPS evidence.

## Retained Balance Failures

Natural current-AI Gem Grab sample: 24 baseline rounds, 16 mirrored difficulty
matches, 2 mutator checks completed; seed offset 300000, unchanged source
fingerprint `a645c849380b0e3c8ffdcd7b1321fde07e919a62d018d04189325b55d2dfdd7b`.
Expert placement share 0.4638554; retained warning:
`expert bots no better than easy`.
Report `/tmp/kras-a918910-gem-report/report.json`, log
`/tmp/kras-a918910-gem.log`.

The independent Scrap Karts sample also retained this difficulty warning, as
recorded in `nearest-rival-ties-2026-10-07.md`. No thresholds or sample seeds
were weakened to hide either warning. Linux campaign 37526080082 remained live
on d1a5a31 and cannot qualify a918910 or integrated code. The game catalogue is
not certified as 39 READY games.

## Production and Release Gates

Fresh read-only production `/health` returned `ok=true`,
`authentication_ready=true`, `multiplayer_enabled=false`.
This neither migrates the production database nor proves positive native auth.

Required before review submission:

1. Full immutable integrated-source Godot/server/network qualification.
2. Resolve retained balance warnings and obtain current all-game evidence.
3. Physical iPhone/iPad portrait/landscape gameplay and measured frame-time,
   memory, thermal and energy qualification. Scripted headless tests do not prove
   any of these measurements.
4. Approved source integration into the production branch, durable database
   backup/restore qualification, safe production account migrations, coordinated
   protocol-2 server/client rollout, endpoint configuration and actual Internet
   reconnect/lobby/tournament acceptance.
5. Verify all product requirements against the current implementation; green
   regression alone does not certify missing/polish requirements as complete.
6. Inspect ASC build inventory, set new Version/Build, freeze/push source, and
   build a NEW local Xcode 27 Distribution archive with exact-source evidence.
   Existing 1.1.10 (107) development QA builds cannot be reused as a new upload.
7. Verify the archived app's identity/version/build/signature, upload, wait for
   processing, select the correct build, complete review metadata and verify the
   submission state separately. No Xcode Cloud invocation.

No Archive, Distribution signing, upload, processing or Apple review submission
has been performed for this integrated source.
