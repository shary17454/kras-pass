# Balance evidence aggregation

`tools/balance-report.mjs` verifies campaign identity and complete per-game
coverage before counting matches. Required evidence: matching 40-character
source/checkout commit, matching run ID, registered unique game ID, natural
round mode, 24 completed baseline rounds, 12 completed difficulty comparisons,
and two successful smoke rounds. Mixed sources, missing/duplicate games,
clipped rounds, incomplete samples and critical findings fail qualification.
`--partial` is explicit and reports missing games; it never implies completion.

Review warnings remain visible. Raw character win totals are not labelled win
rates: no exposure-normalized rate is inferred from those totals. The summary
always leaves `balanceReviewComplete` and `releaseReady` false; complete
simulation coverage alone does not prove balanced or enjoyable gameplay.

The optional campaign summary CI job downloads all report artifacts and runs
this check against the workflow commit/run, retaining its output. It requires
read-only Actions permission, also granted on the reusable workflow caller.
This job is for subsequent campaigns; it cannot modify a running older run.
Its YAML and shell syntax were checked locally; execution remains unqualified.

## Verified Results

- 17 focused Node tests pass: identity mismatch, mixed run, clipped sample,
  missing/duplicate games, incomplete baseline/difficulty, smoke failure,
  warnings, malformed counts and critical findings.
- Actual downloaded artifacts from run `37108335239`, source
  `0b21cac95075705a3ee85641e33e3aa680bcd879`: nine qualified reports, 342 matches;
  explicit partial output names 30 missing games.
- Full mode rejects that same incomplete set with exit 1.
- Findings in that nine-game snapshot: character advantage in ring_rumble,
  slot advantage in tank_arena, weak Expert/Easy separation in fawda,
  goal_guard, magnet_court and storm_heart. These remain review items, not
  balanced-game declarations.
- Final full server suite `/tmp/kras-balance-report-server-final.tap`: 137
  passed, zero failed or skipped. Its six Godot captures come from the earlier
  ball-delay regression source, not the later Tag change.

The initial full server pass attempt had 135 passes and one failure,
`timeout hello`, plus unhandled rejections after test completion
(`/tmp/kras-balance-report-server.tap`). The same WebSocket test passed alone
(`/tmp/kras-websocket-baseline.tap`). The test now observes connection/hello
and welcome/restored promises together, removes timed-out waiters and clears
pending timers during cleanup. The five-second deadline is unchanged: genuine
connection delays still fail rather than being hidden by a longer timeout.
No production WebSocket behavior was changed by this harness repair.

The ongoing original campaign is not cancelled or restarted. Remaining gates
include its terminal reports, balance review/remediation, fresh final-source
regression/network QA, device testing, signing/archive and Apple submission.
