# Dodger Visible Motion Qualification

Date: 2026-10-04
Base: d578fb7329eadf46595d89174af0de5783bc860b
Branch: fix/kras-dodger-visible-motion

## Defect and Fix

Sweeper Storm's dodger read the hazard's private `current_speed()` directly
and its current transform without reaction delay. It also targeted hidden
arms and used private collision reach rather than rendered geometry.

The regression failed seven assertions before the fix (4 passed, 7 failed):
`/tmp/kras-dodger-baseline.log`. There were no script errors in that baseline.

The dodger now records the visible arm mesh's origin, direction and extent at
the shared 20 Hz perception sampling rate. Angular velocity is inferred from
successive visible transforms. The aligned history retains at most 32 samples.
Decisions use the difficulty's reaction delay, not the current private hazard
schedule. Hidden meshes and visibility gaps cannot reveal motion. Round reset
clears observations, jump timing and encounter cooldown.

This is visibility-in-tree filtering, not camera-frustum or wall-occlusion
perception. Those wider perception requirements remain unqualified.

## Local Tests

Godot 4.7.1, local macOS headless runtime:

| Check | Result | Log |
| --- | --- | --- |
| Dodger perception | 93 assertions passed | /tmp/kras-dodger-complete.log |
| Shared AI visibility | 2022 assertions passed | /tmp/kras-dodger-ai.log |
| Real sweeper collision | 31 assertions passed | /tmp/kras-dodger-impact.log |
| Survival round reset | 31 assertions passed | /tmp/kras-dodger-survival.log |
| Sweeper networking | 26 assertions passed | /tmp/kras-dodger-network.log |
| Compile | 329 scripts passed | /tmp/kras-dodger-compile.log |

All completed logs passed `tools/check_godot_log.sh`; test logs also required
positive completed assertion summaries. `git diff --check` passed.

357 script, scene, resource and JSON inputs plus the project settings were
included in the source-input comparison (357 total, no mismatches). Runtime:
`/tmp/kras-cloud-export-uid-check`. This is an owned runtime mirror, not a
release checkout; its Git metadata does not establish release provenance.

## Natural Match Sample

Command: `tools/balance_sim.tscn -- --only=sweeper_storm --runs=24
--seed-offset=100000`, headless fixed simulation timestep 60, natural rounds.

Report: `/tmp/kras-dodger-qualified-balance/report.json`
Log: `/tmp/kras-dodger-qualified.log`

- 24 ordinary matches completed, no draws or missing outcomes.
- 16 matched-seed, matched-character difficulty samples completed.
- Mutator and chaos matches completed: 42 matches total.
- Slot bias: 0.041667; character bias: 0.375.
- Expert metric: 0.518519; two review flags remain: `character advantage`
  and `expert bots no better than easy`.

This sample proves ordinary round completion and detects remaining balance
issues. It does not certify balance, device frame rate, thermals, memory,
touch usability or production multiplayer. No thresholds were relaxed.

The historical full-39 campaign 37154262693 qualifies source
99d1b00d155d00c6faa372780fe26f5a152b8c6e, not this source. The running
campaign 37158410965 qualifies a9d06b20832aa497b1c2b813c75024ec5ff12715.
Neither can qualify this subsequent perception or physics change.

## Apple Read-Only Check

The local Chrome session is authenticated to App Store Connect; the separate
in-app-browser Apple login page is not evidence that all local sessions lack
access. Application 6801506973 is Kras Pass. The distribution page shows
1.1.10 / Build 107, Ready for Distribution. TestFlight Build Uploads shows the
latest chronological upload as 1.1.10 / 107, Complete, Sep 28, 2026.
An older 1.1.8 / 108 upload also exists. Do not choose a new build number from
the project settings alone; recheck all applicable uploads before release.

No App Store metadata was changed, no new build uploaded, and no submission
sent in this qualification. The existing released build is not proof of the
current source. Integration, full-source CI, balance, physical iPhone QA,
Railway production online qualification and signed release archive still
remain separate release gates.
