# Boss report evidence qualification

## Source and scope

Base: `88dafac8ed88ec56f96636fb5b1ccdc5b9d3a1c6`.
Branch: `fix/kras-boss-report-evidence`.

The campaign aggregator previously accepted a completed boss round without
checking whether its objective was defeated, survived, or unknown. The new
validator checks every baseline outcome against its configured seed, rejects
missing or unknown outcomes, and recomputes the counters rather than trusting
the report totals. Zero defeats must retain the existing balance-review warning;
a contradictory warning is rejected too.

The CLI obtains boss IDs from `data/minigames.json`, not from the submitted
report. The per-game CI coverage check uses the same exported validator. Summary
output includes `bossBaseline` counts; it still explicitly sets `releaseReady`
and `balanceReviewComplete` to false.

## Executed checks

- Regression baseline before the implementation: 39 passed, 14 failed; each
  failure exposed an accepted invalid boss report.
- After the implementation: all 53 balance-report tests passed, including
  missing fields, invalid counts, unknown outcomes, duplicate/wrong seeds,
  independent seed offsets, and contradictory review flags.
- The saved Forge instrumentation smoke report passed objective validation:
  two defeated, zero survived, zero unknown. This is the existing **clipped**
  two-match report, not a new natural campaign or release qualification.
- Removing its outcome list was rejected as missing objective evidence.
- Server suite in the local system session: 173 tests, 167 passed, six skipped,
  zero failures. Initial sandbox execution could not listen on `127.0.0.1`;
  rerunning with local system permission resolved that environment restriction.
- Workflow YAML parsing and `git diff --check` passed. YAML parsing does not
  prove a GitHub workflow execution.

## Current production observation

Railway deployment `fc8f01cb-d89f-402b-9332-f3c3699c892d` reported SUCCESS from
main commit `88dafac8ed88ec56f96636fb5b1ccdc5b9d3a1c6`. The bounded startup log
showed no runtime error and did show the configuration-as-code deprecation
warning with a 2026-12-01 deadline. No duplicate deployment was requested.

This branch's new validator is not part of that deployment. It does not enable
production multiplayer, fix remaining balance signals, refresh device signing
profiles, or establish physical-device performance, an App Store archive,
upload, processing, or review submission. Natural boss objective evidence in
difficulty and mutator samples remains to be instrumented and qualified.
