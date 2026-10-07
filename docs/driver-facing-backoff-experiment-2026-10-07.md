# Rejected driver facing-backoff experiment

Parent: `968aab7829e5a8484f540a710c67f96adfe68d19`.
Initial candidate: `0775e7be11cd4b41c91b0c161b9abbdcb200f01d`.
Overlap-corrected candidate: `7e14901484f17aa4e3826cba78014269ce9f43b4`.
Branch: `experiment/kras-driver-facing-backoff`.

Decision: do not adopt this tactic as a balance repair. Gameplay and the
driver-engagement suite were restored byte-for-byte to the parent. Candidate
commits remain in history for inspection; neither was merged to main.

## Hypothesis and behavioral checks

The candidate reversed while keeping its nose toward an observed rival ahead,
only with safe space behind. Rear/side rivals and edge recovery retained the
existing forward peel-off. No character stat, AI profile, physics parameter,
perception delay or balance threshold changed. This is a tested policy
hypothesis, not proof that the original turning tactic is a product defect.

The geometry fixture isolates observation, disables live physics and uses
accuracy 1 only in the fixture. It then exercises actual DRIVE integration.
Original policy: 33 pass, eight expected-policy failures across four tiers
(`/tmp/kras-driver-facing-red.log`). Initial candidate: 41 pass, then expanded
guards 61 pass. An additional overlap test exposed a candidate regression:
61 pass, four fail (`/tmp/kras-driver-facing-overlap-red.log`). Corrected
candidate: 65 pass, strict guard passed
(`/tmp/kras-driver-facing-overlap-green.log`). These assertions establish the
requested maneuver and guards, not natural balance superiority.

## Natural evidence

Every report contains 24 baseline matches, 16 matched seed/character difficulty
matches and two stress checks. Independent validation confirmed all eight
difficulty pairs and unchanged source fingerprints at start/end. All runs
exited zero and passed strict runtime log guards. No selected failure seed or
acceptance threshold was changed after seeing results.

| Source | Offset | Expert share | Character bias | Seat bias | Warning |
| --- | --- | --- | --- | --- | --- |
| Prior runtime d5524b9 | 1200000 | 0.493750 | 0.083333 | 0.083333 | Expert no better than Easy |
| Initial 0775e7b | 1200000 | 0.515528 | 0.083333 | 0.125000 | Expert no better than Easy |
| Corrected 7e14901 | 1200000 | 0.515528 | 0.083333 | 0.125000 | Expert no better than Easy |
| Parent 968aab7 | 1500000 | 0.596273 | 0.041667 | 0.041667 | none |
| Initial 0775e7b | 1500000 | 0.581250 | 0.083333 | 0.041667 | none |
| Corrected 7e14901 | 1500000 | 0.575000 | 0.083333 | 0.083333 | none |

All baseline tie rates are zero. The first limited improvement does not remove
the warning; the independently compared second cohort is worse than the
parent in Expert share and seat disparity. Unflagged execution in that cohort
is not evidence that the tactic improves balance. We therefore reject it,
rather than adopting the passing behavioral fixture as a substitute for the
actual product requirement.

The d5524b9 and 968aab7 gameplay is identical; the parent adds only a development
trace and reports. Its 16 traced paired outcomes also matched the original
reference exactly. The new parent cohort ran from a separate detached checkout,
`/tmp/kras-facing-backoff-parent-968aab7`, not from edited candidate files.
Its initial import completed naturally before a requested TERM could reach
the already-exited process. Matching imported asset cache was then reused and
a second import passed; asset/source Git differences were zero. Both import
logs are retained: `/tmp/kras-facing-parent-import.log` and
`/tmp/kras-facing-parent-cached-import.log`. No other process was stopped.

Fingerprints: parent 274 files
`e4de1862c596dd6d865362f1ece93c10f1ade749356ef22d544ffc91bbdfbb73`;
initial candidate 274 files
`1bf911f7d1950629fade0e0fca76019a6260c5c86422a3b0ea91573d6e9d982f`;
corrected candidate 274 files
`e349d6843979842febd52d9d1df673d2238b96a4ee96e21520d5914fa706cb6c`.
Original reference fingerprint is recorded in the prior current-source report.
Five raw new reports: `docs/qa/driver-facing-backoff-2026-10-07/`.
The existing parent first cohort remains at
`docs/qa/current-source-balance-2026-10-07/scrap-natural.json`.

## Restoration and remaining scope

After restoration, `git diff --exit-code 968aab7 -- src scenes data tools
project.godot tests server` passed. The original engagement suite passed 25
assertions, strict guard passed: `/tmp/kras-driver-facing-restored.log`.
No candidate full regression, server, online or physical-device acceptance is
claimed. No release archive or Apple action occurred.

The Scrap difficulty deficit remains open. The next diagnosis should examine
whether ram boosts are committed toward an observed rival or during an
unfinished turn; do not infer its cause from this rejected experiment.
All39 campaign 37670303689 remains on d5524b9 and must not be attributed to
either candidate. Main, protected production data, Railway and Apple remain
unchanged. Preserve the full product scope and release gates.
