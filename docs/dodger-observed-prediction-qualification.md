# Dodger Observed Prediction Qualification

Date: 2026-10-04
Base: 4dc5d397a44ed169b940afd532afb692716d0509 (PR #35)
Branch: fix/kras-dodger-observed-prediction

## Change

After delayed visible-motion perception, the dodger still treated the retained
arm angle as its present angle. That made its jump estimate late and ignored
the existing difficulty profile's prediction skill.

The arm is now extrapolated from the observed angular velocity, multiplied by
the existing prediction strength clamped to [0, 1]. The extrapolation horizon
is limited to the reaction delay plus one perception sample interval. No
private angular rate, acceleration schedule, collision reach or unseen
reversal is read. Physics, character stats and balance thresholds are unchanged.

Regression before implementation: 107 passed, 10 failed, no script errors,
`/tmp/kras-dodger-predict-baseline.log`.
Pure delay tests explicitly set prediction to zero so they continue testing
observation delay independently of trajectory estimation. New tests exercise
both rotation directions, partial/zero/full prediction, out-of-range profile
values, unsampled reversal and a stale observation horizon.

## Local Qualification

Godot 4.7.1, local macOS, headless:

| Check | Passed | Log |
| --- | --- | --- |
| Dodger perception and prediction | 117 | /tmp/kras-dodger-predict-fixed.log |
| Shared AI visibility | 2022 | /tmp/kras-dodger-predict-ai.log |
| Survival round reset | 31 | /tmp/kras-dodger-predict-survival.log |
| Sweeper host/guest state | 26 | /tmp/kras-dodger-predict-network.log |
| Real sweeper collision | 31 | /tmp/kras-dodger-predict-impact.log |

2227 assertions passed; all logs passed the Godot failure guard and positive
completed test summary check. Compile: 329 scripts passed, log
`/tmp/kras-dodger-predict-compile.log`. Source-input mirror check: 357 compared
scripts/scenes/resources/JSON/project inputs, no mismatches. Runtime mirror:
`/tmp/kras-cloud-export-uid-check`; its old Git metadata is not release evidence.

## Matched Natural Sample

Both reports use 24 ordinary matches, 16 difficulty-paired samples and two
mutator/chaos matches, with natural round endings, fixed simulation timestep
60 and seed offset 100000. A structured comparison confirmed identical
baseline seeds, difficulty seeds/characters/slots and stress seeds.

Before: `/tmp/kras-dodger-qualified-balance/report.json`
After: `/tmp/kras-dodger-predict-balance/report.json`
After log: `/tmp/kras-dodger-predict-balance.log`

| Metric | Before | After |
| --- | --- | --- |
| Expert metric | 0.518519 | 0.549383 |
| Character bias | 0.375000 | 0.250000 |
| Slot bias | 0.041667 | 0.083333 |
| Draws | 0 | 0 |

The insufficient Expert separation flag disappeared for this sample; character
advantage remains. These are sample measurements, not a statistical proof of
universal improvement. Slot bias increased; it is not an all-metrics win.

## Independent Natural Sample

Seed offset 200000, same 42-match structure:
`/tmp/kras-dodger-predict-independent/report.json`
Log: `/tmp/kras-dodger-predict-independent.log`

Expert metric 0.531250, character bias 0.333333, slot bias 0.083333, no draws.
Both stress variants completed; character advantage remains flagged.
84 current-source full matches completed across the two seed offsets without
missing results or engine errors. This does not qualify all 39 games, device
performance, production networking or final character balance.

## Signing Gate Checked Without Changes

Local `security find-identity -v -p codesigning` returned two valid identities,
including the requested Apple Distribution: Shary ALADHYANI (4HM66AD594).
No P12 was imported, no password requested, no certificate created/revoked.

Local structured inspection decoded 73 provisioning profiles without failure.
App Store profile 91bc3a38-3753-4ed6-9f8b-a26974ff9d5e matches
com.shary.kraspass, team 4HM66AD594, Sign in with Apple and the requested
Distribution certificate; expires 2027-09-19. The authenticated local Chrome
Developer portal shows profile 35LZY55A6R, Kras Pass App Store Xcode 27
2026-09-20, Active, same Bundle ID/team/expiry and enabled Apple sign-in.

The installed development profile includes the intended test phone but not
the current local Development identity. It must be refreshed using existing
credentials before physical-device testing; a Simulator build does not close
this gate. No profile or portal setting was changed here.

## Remaining Work

Character balance and broader AI perception still need qualification. Full
current-source CI, integration to the release branch, physical iPhone/iPad QA,
production online qualification, a newly numbered and source-proven signed
archive, upload processing and actual review submission remain separate gates.
This change is not a claim that the full product or release is complete.
