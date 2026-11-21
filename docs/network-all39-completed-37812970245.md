# Completed 39-game network campaign

GitHub run 37812970245 finished successfully with 41 completed jobs.
https://github.com/shary17454/kras-pass/actions/runs/37812970245

Tested checkout: 78d11abdb35144a6c754414487606093dd5c1435.
This is earlier than the current feature branch, not current-source release
acceptance and not a production Railway test.

Downloaded all 40 artifacts (39 games plus core). Every source receipt has
the intended checkout commit and an empty tracked-change field. Actual log
JSON contains 174 PASS groups, 532 peer results and 348 result records with
reconnected=true. These count test groups and peer records, not unique users,
matches or distinct reconnection interruptions. Every game's artifacts include
both two-human and four-human cases, ordinary matches and tournaments. The
host reconnected in every PASS group and peers agree on final scores.

The workflow additionally exercises selected sudden-death finals, restored
Fawda final state and a four-peer mixed no-repeat tournament. Those specialized
cases are not asserted for every game. This is real multi-process Godot and
WebSocket testing on Linux with scripted inputs, not human-input mobile QA.

Raw receipts, peer logs, PASS outputs and timing reports are preserved in
../qualification-network-37812970245-2026-10-08/.
The download was originally /tmp/kras-network-37812970245-completed-evidence.

Later gameplay differences affect shared Fighter, BallBrain, DodgerBrain and
offscreen player cues. The later native pause presenter UID is also different.
Consequently all-game current-source networking still needs qualification.
Native iOS launch, touch/controller operation, energy/thermal performance,
production backup/migration/connectivity, signed archive, upload processing
and App Review remain separate gates. None is proved by this campaign.

The core workflow now includes both iOS export-log and simulator-architecture
Node tests, so those new tool checks cannot silently disappear from CI.
