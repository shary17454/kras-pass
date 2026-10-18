# Rising Tide Ledge Contest Qualification

## Scope

The climber previously waited beside same-level rivals when no higher observed
route was available. Water could eliminate those rivals in the same batch,
producing frequent legitimate ties. The existing simultaneous-elimination
ranking contract remains unchanged.

The climber now contests the nearest visible, reaction-delayed rival within
four meters on its current level when it has no higher route. Existing
aggression, movement, dash safety and character rules apply. Higher routes
retain priority. No privileged perception, new attack action, speed bonus,
timer, water, scoring or winner-rule change was introduced.

## Source And Local Tests

Tests used `/tmp/kras-tank-pursuit-check`, extracted from the clean parent
checkout with the candidate files copied from the working tree. The three
candidate source/test files were byte-compared successfully after testing.
Natural reports have matching start/end runtime fingerprints:
`76e256d502b981e4b3047d73dd7c015912f779aa08e77a3f298990252f63e4b6`.

- New regression: 26 assertions, exit 0.
- Delayed ground/water perception: 110 assertions, exit 0.
- Eight-character, four-spawn climbing regression: 140 assertions, exit 0.
- Simultaneous elimination/scoring contract: 7 assertions, exit 0.
- Compile check: 448 scripts, exit 0.
- Full regression: 406943 assertions, exit 0; 339.5 seconds wall time.
- Full engine log passed the strict completed-test/error/leak gate.
- The initial missing-helper test failed before implementation. Two intermediate
  fixture expectations failed and remain preserved; the final fixture tests
  the actual route and jump-preparation contract instead of raw movement drift.

## Natural Balance Samples

Each sample completed 24 baseline matches, 16 mirrored difficulty matches and
two mutator matches: 84 matches total. Both logs passed strict runtime checks;
neither sample reported balance flags.

| Sample | Tie rate | Mean simulated duration | Expert edge | Spawn bias |
| --- | --- | --- | --- | --- |
| Adjacent roster, offset 10100000 | 12.5% | 16.5375s | 0.7000 | 0.0000 |
| Balanced roster, offset 13100000 | 4.2% | 15.0826s | 0.7101 | 0.0700 |

The earlier offset-10100000 campaign at
`d9841d2543f216bb1d989fd1dd7525e903c36d95` reported 45.8% ties.
Its climber, Rising Tide and game/arena definitions match the pre-candidate
implementation. Other shared runtime changed since that older campaign, so
this comparison is not an isolated whole-project A/B proof. These samples do
not certify all 39 games or phone performance.

Evidence: `../qualification-tide-contest-2026-10-10/`.

## Separate CI And Remaining Gates

Core run 37993021368 succeeded at the previous committed source
`5fe84cd25a1ee6032a6c81d80af4e5ac45eb0f89`, not this candidate.
Tank run 37993034226 failed at that same source: the four-human tournament
reached tank_frost round two without observed armor damage despite shots and
inventory. Original failure artifacts remain at
`/tmp/kras-tank-failure-5fe84cd-37993034226/`.

Current-source CI, that tank failure, remaining balance/content reviews,
physical-device/controller/performance QA, authorized production database and
deployment checks, and a new exact-source signed archive remain open.
No main promotion, production deployment, Apple upload or review submission
is qualified by this phase.
