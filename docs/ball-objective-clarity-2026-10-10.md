# Ball objective clarity qualification

## Scope

Parent source: `9b88f560c13e54655399aa54615091ea9e397cf8`.
Changed only the Arabic and English descriptions for Magnet Court, Storm Heart,
and Sky Court. The HUD already displays these localization keys. The new text
states the defensive objective and highest remaining score victory condition.
Detailed rules, physics, inputs, scoring, character stats, and timers are unchanged.

## Candidate checks

- Structured JSON comparison: identical key sets and order; exactly three
  description values changed in each locale; all other values unchanged.
- Both candidate locale files match the tested temporary project byte for byte.
- Content suite: 121 assertions passed; strict test log check passed.
- Arabic render: six captures, zero failures, runtime log check passed.
- Final English render: six captures, zero failures, runtime log check passed.
- Coverage: three games, four human touch slots, portrait and landscape,
  Arabic and English. These are short desktop-rendered gameplay captures,
  not completed human matches or physical-device performance tests.
- Manual inspection included Arabic Sky Court portrait/landscape, final English
  Sky Court portrait, and final English Magnet Court portrait. The longer initial
  English description left a single word on a second line; it was shortened and
  captured again. Not all twelve images received individual manual inspection.
- `git diff --check` passed.

## Evidence

Local logs and reports, retained separately from source:

- `/tmp/kras-clear-goals-content.log` and `.stdout`
- `/tmp/kras-clear-goals-ar.log` and `/tmp/kras-clear-goals-ar-save/visual-report.json`
- `/tmp/kras-clear-goals-en-final.log` and `/tmp/kras-clear-goals-en-final-save/visual-report.json`
- Initial English render: `/tmp/kras-clear-goals-en-save/`

Core CI for the unchanged parent runtime completed successfully:
https://github.com/shary17454/kras-pass/actions/runs/37997070688
This does not count as a full-suite run on the new localization candidate.
The existing all-game balance campaign remains pending:
https://github.com/shary17454/kras-pass/actions/runs/37997079439
It was not cancelled or replaced by this text-only change.

## Open acceptance gates

A separate natural Sweeper Storm campaign on the parent runtime completed 146
matches (96 baseline, 48 difficulty, two mutator). Its baseline character-advantage
flag remains open: Sakhra won 27 of 96 matches; character bias was 0.15625.
Report: `/tmp/kras-sweeper-current-natural-report/report.json`.
No gameplay tuning or acceptance thresholds were changed to conceal this result.

Stage 0 remains QA/MERGE pending. This batch does not certify all 39 games READY,
physical-device smoothness, production connectivity, or Apple release readiness.
No main promotion, Railway deployment, archive, upload, or submission is included.
