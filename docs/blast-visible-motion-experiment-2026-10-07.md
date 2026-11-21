# Rejected Blast Ball Visible-Motion Escape Experiment

Retained runtime: `c45d304a12df3ad56ecff5eee922de91c0937eba` (PR 146).
This branch does not change shipped gameplay. Its generated patch is archived
as `blast-motion-rejected.patch` for reproduction, not automatic application.

The candidate selected among eight bounded escape directions using closest
linear approach over a short prediction-scaled horizon. It used delayed
observed ball velocity, own walking speed and public floor geometry. No live
ball state, extra speed, difficulty thresholds or scoring changes were used.

Targeted reproduction: four incoming-path cases failed before (375 passing,
four failing assertions), then passed (379 assertions). Visibility passed
3962 assertions; 396 scripts compiled. Those green results did not qualify
the candidate for retention.

## Natural Comparison

Each report completed 24 baseline rounds, 16 paired difficulty rounds and two
mutator/chaos rounds. The round window remained 90 seconds; no winner was
injected. All completed report log guards passed.

| Seed Offset | Retained Expert Share | Candidate Expert Share |
| --- | ---: | ---: |
| 300000 | 0.472049689440994 | 0.49375 |
| 900000 | 0.48125 | 0.43125 |

These are rank-point shares, not win rates. All reports retained
`expert bots no better than easy`. The candidate improved the first limited
cohort but declined in the independent cohort. It is rejected; no solved
balance or READY status is claimed.

Retained fingerprint (start/end):
`d7f877fa7b4a16c2d6c29ee8a038aa39dcd8209048f98b0494fdc444a87f015c`.
Candidate fingerprint (start/end):
`fd8a989d5beed2401750a93459fa8dacd7f6ecaedd20669d268a0ba183366705`.
The 900000 retained comparison is the previously completed report committed
in `blast-homing-ties-natural-report.json`, not a newly rerun baseline.
The other three reports are committed alongside this document.

Logs: `/tmp/kras-blast-motion-{baseline,red,green,after,independent,visibility,compile}.log`.
The known macOS CA diagnostic is not a gameplay exception or clean-import
claim. Short headless simulations do not qualify physical-device performance.

The candidate and its nine assertions were removed with a scoped patch.
The two runtime/test files now have an empty diff against the retained base.
A restored-source Blast Ball regression passed 370 assertions, exit zero,
with a passing strict log guard in `/tmp/kras-blast-motion-restored.log`.

Next balance investigation should measure homing pursuit and offensive
commitment, rather than assuming constant linear ball travel is sufficient.
Production rollout, physical-device QA, exact-source local Xcode 27 Archive,
signing, upload, processing and App Review remain uncompleted gates.
No main merge, Railway deployment, P12 import or Apple submission occurred.
