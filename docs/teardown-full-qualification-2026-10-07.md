# Full teardown qualification

Repository: shary17454/kras-pass, origin (Git SSH).
Branch: fix/kras-match-teardown-quiescence, PR 181.
Tested commit: aede8c815b32b9183212d6939cb5190dbb183a63.
Tested tree: 948f217e052bab780beb013256183d744b50e029.
The tree was clean before and after the run; this report is added afterward.

## Completed exact-source local checks

Command: `GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`.
Godot 4.7.1 official, headless, fixed simulation FPS 60, isolated saves.
Overall exit 0. Evidence directory: `/tmp/kras-party-check.SKxXCX`.

- All 415 scripts compile.
- Inventory: 514 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- Main suite: 388585 assertions passed, 698.9 seconds.
- Independent Party Race: PASS, actual selected three-lap finish.
- Six independent boss regressions: Colossus seeds 345/9614/172,
  Forge/Dreadnought/Sovereign seed 9614. Every run reported defeated=true.
- Stability: one complete cycle through all 39 games, zero failures.
- Every stage passed its strict runtime/test log guard.
- Node server suite: 204 passed, zero failed/cancelled/skipped, exit 0.
  Evidence: `/tmp/kras-teardown-full-server-tests.log`. All six actual Godot
  KRAS_*_WORLD_FIXTURE captures were taken from THIS gate's saves-tests folder,
  not from the earlier failed full run. Loopback only; no production accounts.

The preceding full failure and fixture correction remain documented in
`teardown-full-regression-followup-2026-10-07.md`; they are not erased or counted
as passing. This new complete run validates the corrected fixture and runtime.

The known macOS CA-access diagnostic is retained. The negative zero-assertion
probes inside balance_sim are intentional tests of a separate harness, not
failures of this main suite. The stability fixture deliberately emits its
memory warning. Cached texture/material/mesh/audio counts reached zero after
settling, while reported process memory remained 140225226 bytes. One short
headless cycle is not evidence of no long-session leaks, physical-device
60/120 FPS, heat or battery qualification.

## Current-parent natural campaign progress

Existing run 37616445234, source 96c53f359cbb48663a9a99d3fec5ecf6e16d16af,
offset 1200000. At inspection four jobs succeeded including catalogue;
workflow remained queued with empty conclusion, no failure. Downloaded the
three available natural-balance artifacts and validated them with:

`node tools/balance-report.mjs /tmp/kras-campaign-37616445234-progress-20261007
96c53f359cbb48663a9a99d3fec5ecf6e16d16af 37616445234 --partial --paired
--seed-offset=1200000`.

126 completed matches for tank_arena, ring_rumble and crumble_court; no review
flags in these three samples. All required per-game source, seed, mirrored
same-character difficulty and stress evidence passed validation. The aggregate
remains incomplete with 36 games missing. Summary:
`campaign-37616445234-partial3.json`. This is parent-runtime evidence, NOT
literal balance qualification for aede8c8. No duplicate run was dispatched.
The older all-39 source still has four review warnings; see its retained report.

## Live Railway read-only verification

The fresh worktree is not locally CLI-linked; `railway status --json` returned
that limitation. No link was changed. Explicit project/environment/service
arguments matched the IDs guarded by `.railway/railway.ts`:
project eb193205-199c-4aab-8aff-1bb532dfb4a3, environment production
cb3cc392-8240-49a9-aeb6-e3894cace30b, service kras-pass.

`railway deployment list --limit 3 --json` verified latest successful deployment
8d235c0c-eac1-4ade-9065-4e3264d36021, created 2026-10-06T01:59:33.330Z,
repo shary17454/kras-pass, branch main,
commit 062a40992b92958573e28e19d8c8c1840560797a. `/data` volume mount,
Dockerfile builder and /health healthcheck were present in deployed metadata.
Fresh `git ls-remote origin refs/heads/main` returned this same commit.

Public production /health returned ok=true, authentication_ready=true,
multiplayer_enabled=false. Filtered error-level deployment logs for the last
24 hours (maximum 50) returned zero rows; only timestamps/count were exposed,
not private log messages. This bounded read is NOT a claim that every log is
error-free, that authentication/subscriptions work, or that new code is deployed.
The production commit is still different from the tested release branch.

## Remaining release gates

Complete current natural balance/playability/perception acceptance, resolve or
explain warnings with adequate evidence, and qualify local 1-4-human controls,
gamepads, portrait/landscape, sustained device performance, accounts/subscriptions,
offline/save/replay behavior. Production backup/restore, source promotion,
coordinated protocol rollout, production auth/API and Internet reconnect remain
unqualified; the previously denied protected operation was not retried.

No main merge, production deploy/database export, phone install, new archive,
upload, processing or review submission occurred. Candidate 111 remains preserved
but does not include teardown changes. A final frozen/pushed release commit and
new LOCAL Xcode 27 Distribution archive are still required before upload.
No Xcode Cloud, P12 import, password request or certificate change occurred.
