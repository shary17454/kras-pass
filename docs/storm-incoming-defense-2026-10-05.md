# Storm Incoming Defense Qualification

Runtime/test source: `3b601bd1adc9d102654c7d5c3c787f9f377ff169`.
Baseline runtime: `d8c27001453f3fb45f56f630f3448a5e58403283`.
Branch: `fix/kras-storm-incoming-defense`, repository `shary17454/kras-pass`.

## Actual Defect and Correction

During the public turbine warning, Storm Heart's keeper selected the centre of
its goal instead of intercepting a previously observed incoming oblique shot.
The new regression failed on all four sides: 17 assertions passed, four failed.
The expected shield contact coordinate was -1.38, but the target was zero.
Log: `/tmp/kras-storm-defense-red.log`.

The keeper now retains its existing interception behavior when its delayed
visible ball sample approaches the actual shield contact plane within the
authored 1.6-second warning horizon. It otherwise retains home positioning.
Outgoing, slow distant, unobserved and absent balls do not override the warning.
No live ball velocity, future volley bearing, character bonus, difficulty
parameter, timer, scoring rule or comparison threshold was introduced.
This fixes a specific decision error, not all AI perception/reaction issues.

Focused final regression: 25 assertions, exit zero, including actual shield
interception on every side and poisoned live velocity to distinguish delayed
samples from current ball state. Existing keeper contact test: nine assertions,
exit zero. Logs: `/tmp/kras-storm-defense-final.log` and
`/tmp/kras-storm-keeper-contact.log`; completed engine log guards passed.

## Matched and Independent Natural-Round Samples

Each sample used eight ordinary baseline matches, sixteen mirrored Expert/Easy
comparisons across all eight characters, and two mutator/chaos checks. Actual
win/elimination rules ended rounds; no clipped-round switch was used.

The before/after sample used `--runs=8 --seed-offset=300000` and identical
baseline seeds 309001, 309614, 310227, 310840, 311453, 312066, 312679, 313292.
The tool's paired difficulty seed and character configurations were unchanged.

| Metric | Before | After |
| --- | ---: | ---: |
| Expert placement share | 0.519230769 | 0.533653846 |
| Expert saves | 235 | 253 |
| Easy saves | 134 | 131 |
| Expert conceded | 268 | 253 |
| Easy conceded | 309 | 319 |

The old sample retained `expert bots no better than easy`; the new sample had
no flags. Independent post-fix seed offset 600000 completed all 26 matches,
placement share 0.528846154, no flags, both smoke checks successful.
Reports: `/tmp/kras-storm-before-report/report.json`,
`/tmp/kras-storm-after-report/report.json`,
`/tmp/kras-storm-independent-report/report.json`.
All three engine processes exited zero; runtime log guards passed.

These marginal small-sample changes do not prove statistically stable balance,
all-map fairness, human difficulty, or resolution of all thirteen campaign
review candidates. No release-ready or balance-review-complete flag was set.

## Exact-Source Full Checks

`GODOT_BIN=/opt/homebrew/bin/godot sh tools/check_party.sh` completed with
exit zero on the unchanged committed runtime/test source above.
Godot: 4.7.1 official, macOS, headless. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.RA3qH0`.
Wrapper log: `/tmp/kras-storm-defense-full.log`.

- All 378 scripts compile.
- Inventory: 418 resources, 21 autoloads, 27 routes, eight characters, zero issues.
- 360404 assertions passed in 604.0 seconds.
- Actual three-lap race regression and all six authored boss probes passed.
- Stability: 39 matches, zero failures.

This wall time is not performance improvement or physical device evidence.
After draining known caches, engine static memory remained 441277610 bytes
after five seconds. Native RAM attribution/long-session leak qualification,
FPS, thermal behavior and battery consumption remain unresolved.

Fresh six Godot world captures from this same suite were supplied to the server:
192 tests passed, zero failures and zero skips, exit zero.
Log: `/tmp/kras-storm-defense-server-captures-local.log`.
The first sandboxed attempt failed with loopback `listen EPERM`; the authorized
local-port retry succeeded without code changes. Do not count the first attempt
as a passing test. `npm audit --audit-level=high` found zero known vulnerabilities.

## Delivery Limits

No automatic main merge, production configuration change, Apple archive,
upload or review submission occurred. Main/Railway still need revalidation
against the eventual approved release commit. The full current-source hosted
network matrix, real Internet peers, original-content polish, broader balance,
physical iPhone/iPad testing, and exact-source Apple Distribution release gates
remain separate requirements. This correction does not complete the full goal.
