# Reacquisition Full Regression Qualification

Tested source: 96c53f359cbb48663a9a99d3fec5ecf6e16d16af.
Runtime change: 99242b886e898cc2c2bea6087eb08364beb350f7.
Branch: fix/kras-rival-reacquisition-delay; PR 179, stacked on PR 178.
Tree remained clean and unchanged while the gate ran. This report is added
afterward without runtime changes.

Command: GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh.
Godot 4.7.1 official, fixed simulation FPS 60, isolated temporary saves.
Overall process exit 0. Evidence directory: /tmp/kras-party-check.KZZpbq.

## Completed Checks

- All 415 scripts compile.
- Inventory: 514 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- Main suite: 388563 assertions, 434.6 seconds, passed.
- Separate actual Party Race regression passed.
- Six separate boss regressions passed: Colossus seeds 345/9614/172 and
  Forge, Dreadnought, Sovereign seed 9614, all reported defeated=true.
- One stability cycle: all 39 matches completed, zero failures.
- Every stage's runtime guard passed.
- Node server suite: 204 passed, zero failed/cancelled/skipped, exit 0.
  All six actual Godot world fixtures were taken from THIS gate's saves-tests,
  not an earlier parent run. Loopback networking only; no production accounts.

Each gate stage retains .log and .stdout in the evidence directory. Server
execution was recorded by exec sessions 95394 (start) and 1018a9 (completion
output chunk). The server command set KRAS_ARMED/SIEGE/FORGE/DREADNOUGHT/
SOVEREIGN/COLOSSUS_WORLD_FIXTURE to the matching *-world.json files in
/tmp/kras-party-check.KZZpbq/saves-tests before npm test.

The system CA-access diagnostic is retained. The two intentionally failing
zero-assertion probes are in test_balance_sim, not main-suite failures. Save,
transport and Replay-budget failures are deliberately injected by fixtures.
The stability fixture injects a memory warning; it is not a phone warning.
Cached texture/material/mesh/audio counts return to zero, but settled process
memory remains approximately 140.2 MB. This does not certify no memory leaks,
long-session performance, battery, heat or physical-device FPS.

## Current-Source Natural Campaign

After verifying no existing campaign for this branch, dispatched
balance-campaign.yml with seed_offset=1200000. Verified actual run:
https://github.com/shary17454/kras-pass/actions/runs/37616445234
headSha=96c53f359cbb48663a9a99d3fec5ecf6e16d16af, status=queued,
conclusion empty at inspection. No success or release readiness inferred.

This requests 24 authored-duration baseline matches, 16 mirrored same-seed/
same-character difficulty matches and two stress matches for every registered
game. The existing old-source run 37577604329 was not cancelled or restarted.
Its outcomes cannot qualify this changed shared AI code.

## Remaining Gates

Collect and validate actual campaign artifacts and resolve any warnings; audit
playability, physical 1-4-player input/orientations/gamepads, sustained device
performance and account/subscription/offline/save behavior. Production protocol,
auth, database rollout and Internet reconnect/tournament acceptance remain
unqualified. The protected production operation previously denied was not
retried. Pending device-install approval was not assumed.

No main promotion, Railway deployment, new archive, upload, processing or Apple
review submission occurred. Archive 110 is still an earlier source. A final
frozen, pushed source and locally built Xcode 27 Distribution archive are required
before upload; no Xcode Cloud was used.
