# Sweeper resistance diagnosis

Source checkout: `c7377eb84f300e8b5b872ad657ac0952bf87a1d3`.
This is a completed diagnostic experiment, not a gameplay fix or release approval.

## Experiment

Ran the existing `tests/sweeper_resistance_experiment.tscn` with Godot 4.7.1,
headless fixed 60 FPS, isolated saves, 96 balanced-roster baseline matches,
seed offset 13100000, 48 matched difficulty matches, and two mutator matches.
The experiment neutralizes fighter knock resistance only. It does not change
speed, acceleration, jump, power, handling, health, or production saves.

All 146 matches completed, zero invalid contact records. Runtime log check
passed; source fingerprint was unchanged across the run:
`ac53d83e830554ed48e52f1d404104f8c9d3f20117e91eb0a4bff421e3abc063`.
547 tracked runtime/content/tool files matched the qualified temporary copy.
The experiment script matched separately with SHA256
`c8b16f507b4bacdd5a63a5435a0ff19b53b0507d2955d7d01e85272f8fb31bc7`.

Isolation suite: 69 assertions passed, strict test log check passed. It checks
unchanged non-resistance fields and rejection of counterfactual evidence as
natural release evidence. Report sample mode is `counterfactual_resistance`.

## Matched comparison

The natural baseline is the unchanged parent runtime at 9b88f56. Its source
fingerprint differs because the later localization descriptions changed.
Baseline roster arrays and difficulty seed/character/expert-seat arrays matched
exactly in the comparison; the natural report is not relabelled as the candidate.

| Metric | Natural baseline | Neutral resistance experiment |
|---|---:|---:|
| Sakhra wins / 96 | 27 | 17 |
| Character bias | 0.15625 | 0.0520833 |
| Slot bias | 0.0729167 | 0.0625 |
| Expert point share | 0.540541 | 0.510417 |
| Mean simulated duration | 31.2036 s | 30.1172 s |
| Flag | character advantage | expert bots no better than easy |

The resistance intervention reduced the sampled character advantage, but
introduced a difficulty-quality warning. Do not ship neutral resistance as
the solution or mark this minigame READY. This single cohort does not prove
universal causality or held-out balance.

## Next qualification

Investigate hazard-local resistance compression without changing character
identity or combat mass globally. Recheck natural baseline and candidate with
matched and independent cohorts, and investigate legal observed-motion jump
timing if difficulty remains weak. Do not lower acceptance thresholds or alter
results to remove warnings. No gameplay data or runtime was changed here.

## Retained evidence

`../qualification-sweeper-resistance-2026-10-10/` contains the natural report,
counterfactual report, contact records, progress files, and engine logs.
Isolation test logs are retained there as well.

The existing all-39 campaign `37997079439` remains active on source 9b88f56;
it was inspected, not restarted or cancelled. Local completion does not certify
that campaign, physical-device performance, production networking, or Apple
submission. Stage 0 QA/MERGE gates and the full product goal remain open.
