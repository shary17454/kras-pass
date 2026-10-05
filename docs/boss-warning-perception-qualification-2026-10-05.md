# Boss warning perception qualification

## Product correction

Boss AI previously consulted every controller danger zone immediately. Comparing
the warning's remaining duration with reaction time did not actually delay its
first reaction or check whether the warning was visible.

Warning metadata now identifies its existing rendered cue: telegraph ring,
Colossus crater, or Dreadnought mine. Boss hunters use the shared camera/frustum
and occlusion observation test, remember when each visible cue was first seen,
and wait their configured reaction delay. Hidden, removed, and off-screen cues
lose that observation credit. Round restart clears the cache. Delayed perception
feeds the existing escape decision, rather than a separate unused validator.

No damage, health, exposure duration, time limit, character stats, network
protocol, or victory condition changed. Navigation ground-clearance protections
remain in place. This is not a claim that every boss weak-point/feeding cue or
every specialised AI controller has a complete perception layer.

## Source and regression checks

- Parent: `3997a91f4ab2321a0e5bdf0e0a4f38e3c1a6047a`.
- Runtime correction: `e1756ee8945d3f7209108af3446ef8e41e63098b`.
- Visible warning suite: 48 assertions, exit 0,
  `/tmp/kras-boss-warning-perception-final.log`. Actual four-boss scenes cover
  fresh/delayed/hidden/reappearing/off-screen/removed cues and round reset.
  Actual Colossus decisions attack before the delay and flee after it.
- Safe Colossus approach: 112 assertions, exit 0,
  `/tmp/kras-boss-warning-approach.log`. Its navigation-only fixture explicitly
  uses zero reaction time; the separate perception suite tests real delay.
- Boss round lifecycle/reset: 740 assertions, exit 0,
  `/tmp/kras-boss-warning-reset.log`.
- Compile check: 361 scripts, exit 0, `/tmp/kras-boss-warning-compile.log`.
- Explicit log scan found no script/native errors, crash or leak markers in
  these successful checks. `git diff --check` passed.

## Matched natural-round samples

Both commands used isolated HOME and saves, Godot 4.7.1 headless fixed FPS 60,
`tools/balance_sim.tscn -- --runs=2 --only=boss_colossus
--seed-offset=872800000`. Runtime files were unchanged during each execution.
Baseline ran the clean parent; the second run used the clean runtime correction.
Reports have no embedded Git provenance; this mapping comes from the execution
and observed checkout state, not an inferred commit in the report.

| Measure | Parent | Visible delayed warnings |
| --- | --- | --- |
| Medium baseline seeds | 872809001, 872809614 | Same |
| Medium boss defeats | 0/2 | 0/2 |
| Medium duration | 150 s | 150 s |
| Mean medium score | 96.25 | 137.5 |
| Matched Easy/Expert matches completed | 16/16 | 16/16 |
| Boss defeats in matched Easy/Expert matches | 16/16 | 16/16 |
| Expert finishing-place share | 0.65497 | 0.67066 |

Both campaigns returned exit 0 but explicitly flagged `boss never defeated in
baseline sample`. Exit 0 therefore does not establish acceptable balance.
Two medium matches cannot establish spawn or character fairness, and the change
is not presented as a statistically proven score improvement.
Mutator and chaos smoke completed in both runs, with surviving bosses; these are
stability checks, not successful defeat qualifications.

- Parent report: `/tmp/kras-colossus-bot-baseline/report.json`, SHA256
  `d59d1a60450747cd6090edff3027001a6a166fbdab22bf9b25c382867b2feacf`.
- Updated report: `/tmp/kras-colossus-bot-warning-delay/report.json`, SHA256
  `11398a5a4b02046944de57e50fb7bf55ae68322ad1d33006ad3889a8495a103b`.
- Logs: `/tmp/kras-colossus-bot-baseline-valid.log` and
  `/tmp/kras-colossus-bot-warning-delay.log`, no native/script/leak error markers.
- Initial seed offset 1872800000 was rejected with exit 2 because the simulator
  permits at most 1000000000. That aborted command is not a completed sample.

## Remaining gates

Medium boss tactics, contestable openings and character/spawn balance still
require larger independent campaigns. Current-source network and replay checks,
full CI, physical iPhone/iPad controls/performance/thermal tests, Railway
coordination and verified-source signing/archive/upload/App Review remain open.
No automatic main merge, production deployment or Apple submission occurred.
