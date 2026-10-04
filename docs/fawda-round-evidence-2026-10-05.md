# Fawda round evidence, 2026-10-05

## Scope

Add read-only, per-round host/guest diagnostics and retain the failing
four-human tournament seed in CI. No gameplay, bomb lifetime, blast damage,
spawn, movement, result authority or event requirements are changed.

The observer retains one summary per round, not a history for every frame.
It reports phase changes, actual host simulated elapsed time, alive slots,
current bomb count, smallest observed fuse and maximum event generations.
Guest elapsed time is not an independent simulation clock. Every summary
includes host/guest identity, arena, seed and tournament contenders.

## Existing failures retained

- Run 37222295173, intended head
  `48b0589c11879a2454ed8f3a926e6507738608f1`: four humans,
  first tournament match, `storm_ring`, seed `1528023384`.
  Both host and guest logs lack `explode`. This contradicts a diagnosis
  limited to lost guest presentation. The old evidence does not record
  each round's elapsed time or terminal fuse, so the cause remains unproven.
- Run 37230877167, intended head
  `0a60b58f5937ae0f65ea47beb1cd95471a2f869b`, checkout tree
  `5da0711302513362c02629f28569646a3c7ece6c`: two humans plus bots.
  Three ordinary tournament matches observed every bomb event. A fourth
  match, `storm_ring`, seed `1993721724`, ended with only `drop` observed
  on the host and failed the pickup requirement. This is a different failure.

Downloaded evidence:

- `/tmp/kras-ci-fawda-evidence-37222295173/`
- `/tmp/kras-fawda-current-evidence-37230877167/`

## Executed checks

- Before edits, `d55edff975ca35ea3d72c540fb95b1a64680cdeb`, real Godot
  four-human tournament using `--seed=1528023384`: all four peers passed,
  three matches completed, matching tournament standings, host and one
  guest reconnected. Evidence:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-5BihbN/`.
  This local success does not reproduce or resolve the Linux failure.
- Modified source, two-human tournament using `--seed=1988260264`:
  both peers passed, three matches, matching results and reconnects.
  Evidence:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-YOrdPI/`.
  `--seed` fixes every service seed, not the original sequence of changing
  seeds. No final was entered locally. This is diagnostic integration
  coverage, NOT reproduction of the fourth-match failure above.
- Read-only evidence suite: 13 assertions passed, log guard passed.
  `/tmp/kras-fawda-evidence-clean.log`.
- Compile check: all 346 scripts compiled, log guard passed.
  `/tmp/kras-fawda-evidence-compile.log`.
- Workflow YAML parse and `git diff --check` passed.
- The initial sandbox unit attempt failed opening the engine's default
  user log and crashed before testing. Explicit temporary engine logs
  avoided that error; the sandbox rerun passed assertions but emitted a
  macOS system-CA access error. The final authorized local rerun and log
  guard passed. The failed logs remain preserved.

## Release gates still open

Do not call Fawda networking qualified until Linux evidence explains both
failures and the corresponding strict real-peer regressions pass. The
fourth-match case needs exact tournament-seed/contender reproduction, not
replacement with one fixed easier seed. A decisive survival round can end
before a bomb's fuse expires; establish that from actual per-round records
before changing either gameplay or coverage policy.

These tests use scripted inputs, not physical players. Server event-loop
maxima were 5780 ms and 1122 ms respectively; neither run proves mobile
frame rate, battery, thermal or UI quality. No production deployment,
Distribution archive, upload or App Review submission was performed.
