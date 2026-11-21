# Current Source Regression Checkpoint

Verified runtime source: `cbe2124812008bd55746e1d0e50c49087ad2ef74`.
Repository: `https://github.com/shary17454/kras-pass.git`.
Branch: `feature/kras-online-random-rotation`.
Engine: Godot 4.7.1 official.

This is a qualification checkpoint, not completion of the product scope or
authorization to promote the branch to production.

## Current Results

- Complete test runner: exit 0, 407408 assertions, 252.1 seconds.
  `tools/check_godot_log.sh` accepted the complete stdout.
- Stage-zero inventory: exit 0, 554 resources, 22 autoloads, 27 routes,
  8 characters, 39 minigames, 34 arenas, zero inventory issues.
- Content audit: exit 0 and accepted stdout. No structural BROKEN or REWORK
  classifications. All 39 games remain NEEDS_BALANCE because no qualifying
  complete balance report was supplied for this runtime fingerprint.
  Compilation or passing regression does not automatically mark games READY.
- Runtime fingerprint:
  `e4c56526502dda4d61619177508c937cfc0c77369f02c4df9d07114348880ed2`.
- Inventory fingerprint (different scope):
  `e42353ed18642e371551763705e361b267090f970c88b870526aa1a3cb82f1b9`.

The isolated imported runtime was `/tmp/kras-tank-pursuit-check`.
Raw current-run evidence: `/tmp/kras-cbe2124-full.stdout`,
`/tmp/kras-cbe2124-content.stdout`, and that runtime's
`build/stage0/inventory.json` and `build/party/content-audit.json`.
These temporary paths are local evidence, not durable CI artifacts or
signed-archive provenance.

## Work Still Open

- At this inspection, core run 38018319419 was in progress and balance run
  38018326003 was queued. Both target older source
  `15279bfa95aaadeeb081a35c88d477bc81cf8e74`, not this checkpoint.
  They were neither cancelled nor replaced to refresh the source.
- Current-source all-game balance, online qualification, actual-device
  controller, frame-time, thermal and battery acceptance remain open.
- The broader product backlog, including weekly challenges, is not completed
  by these tests. Stage QA and merge gates remain in force.
- Production DB backup/restore authorization and Railway production
  qualification are separate from headless Godot tests.
- No fresh current-source signed Archive, upload, processed App Store build or
  submission to Apple occurred in this checkpoint.

Git fetch succeeded. At inspection, `origin/main...HEAD` had 0 main-only and
425 feature-only commits. The working tree was clean before this document.
No merge, force push, production migration or certificate operation was
performed. This documentation commit does not change the tested runtime.
