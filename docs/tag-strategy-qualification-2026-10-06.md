# Tag Hunt Score-Aware Strategy Qualification

## Source And Behavior

Runtime/test commit: `b9c03a201245370e09950a999cd69be316a00e2e`.
Branch: `feat/kras-tag-score-aware-strategy`, based on the contact-selection
fix in PR #100, `70a781eb8c9ed529835d5899ea61ee2f984dc409`.

Tag Hunt rewards both tags and free time. Previously every non-hunter bot
escaped regardless of score. Higher-strategy bots now accept a role challenge
when at least three public points behind and more than six seconds remain.
Leading bots and lower-strategy bots retain their escape behavior. The incoming
role is still awarded by ordinary physical contact, and subsequent points still
require an ordinary tag. No score, speed, difficulty profile or character stat
was changed. This is a tactical catch-up behavior, not a hidden bonus.

The strategy uses public HUD scores and an already observed hunter position.
Hidden movement does not update that position; a never-observed hunter cannot
be located from the scores. Existing perception/reaction and decision timing
remain in place. The approach does not request an additional dash.

## Regression Evidence

The new fixture failed two assertions before the implementation: a trailing
expert still escaped instead of approaching the observed/remembered hunter.
After the implementation, the AI visibility suite passed 2,091 assertions.
The new checks cover trailing/leading strategy, low-strategy behavior,
insufficient time, legitimate last-seen memory and a never-observed hunter.
The visibility fixture explicitly saves/restores scores and remaining time.

All 386 scripts compiled. The full test runner passed 360,975 assertions in
400.7 s. Runtime log guards passed for compile, full tests, both new strategy
campaigns, the independent baseline and both rendered runs. Source remained
unchanged during qualification, checked against the runtime commit.

Logs: `/tmp/kras-tag-strategy-red.log`, `/tmp/kras-tag-strategy-green.log`,
`/tmp/kras-tag-strategy-compile.log`, `/tmp/kras-tag-strategy-full.log`.

## Two Independent Natural Comparisons

Each report contains 24 natural rounds, 16 matched-seed/character difficulty
rounds covering all eight characters, and two short mutator/chaos smoke rounds.
Both new strategy reports, plus the independently rerun baseline at offset
900000, completed in this qualification: 126 newly executed matches.
The 600000 baseline reuses the preceding frozen contact-fix campaign rather
than pretending it was rerun. Together the four compared reports cover 168
matches. Runtime, test, data and tool files are identical between that baseline
commit `494d475f0f09342964e703df432c55eee6cca9d1` and parent `70a781e`.

`summarizeBalance` validated all four local reports using the committed eight
character IDs, exact source commits, pairing and seed-offset requirements.
The supplied provenance is local checkout evidence, not a GitHub Actions run.

| Seed Offset / Metric | Before | Strategy |
| --- | --- | --- |
| 600000: expert placement-point share | 0.4601226994 | 0.5808383234 |
| 900000: expert placement-point share | 0.5030674847 | 0.6219512195 |
| 600000: average baseline duration | 90.0167 s | 90.0167 s |
| 900000: average baseline duration | 91.2674 s | 91.2674 s |
| 600000: slot / character bias | 0.125 / 0.125 | 0.125 / 0.125 |
| 900000: slot / character bias | 0.208333 / 0.125 | 0.208333 / 0.125 |

The `expert bots no better than easy` flag remains in both baseline reports
and is absent in both new strategy reports. All mutator and chaos smoke checks
passed. This resolves the observed flag in these two samples, not proof of
global balance across every arena, human group or preset. The validator still
returns `releaseReady=false` and `balanceReviewComplete=false`.

Reports:
`/tmp/kras-tag-after-natural-report/report.json`,
`/tmp/kras-tag-strategy-natural-report/report.json`,
`/tmp/kras-tag-strategy-independent-baseline-report/report.json`,
`/tmp/kras-tag-strategy-independent-report/report.json`.

The independent baseline used a separate detached checkout at `70a781e`.
An initial import was started before checkout completion and rejected the
incomplete setup; it was stopped and excluded. Import after checkout completion
succeeded. Sandbox denial of saving global editor settings was environmental;
the subsequent natural run and its runtime guard passed. Import-generated UID
metadata and the temporary baseline checkout were cleaned up afterwards.

## Rendered QA: Open Issues Found

Two separate macOS windows used the mobile renderer, quality 2, a 60 FPS cap,
four Expert bots and an inactive touch-control overlay. Both completed 28 live
wall seconds with at least 25 seconds of steady frame samples and nonzero
movement for every player. Nodes returned from 50 to 50 after teardown.

| Orientation | Mean FPS | p95 | Worst Steady Frame | Frames Over 100 ms |
| --- | --- | --- | --- | --- |
| Portrait | 58.65 | 17.742 ms | 348.814 ms | 3 |
| Landscape | 59.10 | 17.475 ms | 243.090 ms | 2 |

The screenshots were visually inspected and their file dimensions checked:
portrait 720 x 1280, landscape 1280 x 720. The landscape JSON's `output_size`
was captured at startup as 854 x 480 and does not describe the final screenshot.
The fixture needs live/final viewport metadata before size-specific performance
claims. These are macOS measurements, not iPhone FPS, energy or thermal tests.

Visual QA found role notifications overlapping the HUD, particularly the
portrait hunter banner; an old handover toast can remain after the live hunter
changes. This needs UI polish. Near-60 mean FPS does not erase the recorded
frame spikes. Static memory remained elevated after teardown, consistent with
the separately investigated font-cache issue; equal node counts do not prove
all memory is released or establish physical-device stability.

Evidence: `/tmp/kras-tag-strategy-portrait.json` and `.png`,
`/tmp/kras-tag-strategy-landscape.json` and `.png`, corresponding `.log` files.

## Release Boundary

This branch is not merged into `main`, and no production settings changed.
No signed archive, upload or Apple review submission was performed. The parent
PR's CI run `37395320063` was observed queued at head `70a781e`; no CI pass is
claimed. Next work includes the notification/HUD overlap, accurate viewport
profiling, frame-spike attribution and remaining minigame/device/release gates.
Tag Hunt remains NEEDS_POLISH, not READY.
