# Matched difficulty campaign: 37113379841

GitHub Actions run completed successfully on 2026-10-03:
https://github.com/shary17454/kras-pass/actions/runs/37113379841

The strict aggregate validated all 39 artifacts against source commit
`c97cd88e88e9e957120d49027a33494828cb392e`, actual checkout, natural-round
policy, completed samples and matched seed/character pairs with Expert slots
mirrored. There are 1,638 completed matches; no missing games. The saved aggregate
is `balance-campaign-37113379841-summary.json`. It is not a READY certification.

Thirteen games still require review: boss_colossus, drift_floes, duel_pit,
duo_clash, fawda, goal_guard, mnatiq, ring_rumble, sabaq_sawarikh, scrap_karts,
storm_heart, sweeper_storm and zone_hold. Review reasons are retained verbatim in
the aggregate. Seven games flagged Expert difficulty not outperforming Easy,
five flagged character advantage (sweeper_storm overlaps), and two flagged frequent
ties. The sample detects candidates; it does not establish a statistically precise
win-rate estimate or justify hidden speed/aim bonuses.

Next qualification requires inspecting per-match outcomes, legitimate team ties,
elimination/timeout logic, character exposures and perception/decision behavior,
then focused repeated paired simulations and regression tests for any corrections.
Do not mark balanceReviewComplete or releaseReady from a successful runner alone.

Artifacts downloaded to `/tmp/kras-paired-balance-37113379841-retry`; first download
failed on one transient artifact HTTP 401, and the retry succeeded without changing
credentials or rerunning the campaign. Aggregate command:

```sh
node tools/balance-report.mjs /tmp/kras-paired-balance-37113379841-retry c97cd88e88e9e957120d49027a33494828cb392e 37113379841 --paired
```
