# Adventure Boss Objective Qualification

Base: `6da6affd87c5d6eec80c84d866aa5d4bb47c4673` (PR 22).
Implementation: `29fed2b242be9232d1d118acae96c149e549ed2d`.

## Behavior

Previously, first place on damage could clear an adventure boss stage even when the boss survived the deadline. BossController now records numeric `boss_rounds` and `boss_defeats` details at the existing round-finalization hook. Assigning rather than incrementing makes repeated finalization safe. Existing round reset clears those details; normal result aggregation sums them.

Adventure progression checks the registered minigame's boss classification, not only the stage's `boss` flag: some adventure finals use non-boss competitive games. A real boss stage requires recorded participation and defeat in every retained result round. Missing evidence fails closed. A deadline result can still retain damage ranking and participation gems, but grants no clear, win bonus or adventure stars. An outright leading contributor after actual defeat retains the normal clear reward.

No boss health, timer, difficulty, damage, leaderboard ranking, tournament score or save schema was changed. Already unlocked progress is not revoked. The two new numeric detail fields use the existing result-details aggregation rather than a new network/result protocol.

## Tests

- Regression with the exact previous adventure script from PR 22 and the new fixture: 98 passed, six failed. Five assertions expose invalid clear/star behavior; the sixth follows from the earlier wrongly granted first-clear state.
- Final party/progression suite: 104 assertions passed, exit 0.
- All four boss reset/damage/completion suites: 740 assertions passed, exit 0.
- Real completion tests create fresh matches and follow INTRO -> INSTRUCTIONS -> COUNTDOWN -> PLAYING -> FINISH -> RESULTS -> DONE. They verify the callback's round evidence and aggregate details for both a surviving and defeated boss, using the real damage API.
- Final compile: 324 scripts passed, exit 0.
- Diff whitespace check passed.

Logs: `/tmp/kras-boss-objective-baseline-party.log`, `/tmp/kras-boss-objective-party-final.log`, `/tmp/kras-boss-objective-delivery-final.log`, `/tmp/kras-boss-objective-compile-final.log`.

An initial completion fixture attempted illegal phase transitions on a reused DONE scene and failed. Those fixture failures are not production baseline defects. The corrected tests use fresh scenes and legal lifecycle transitions, without weakening the production phase guard.

The sandboxed engine reported a macOS system CA lookup diagnostic at startup. This qualification establishes gameplay and result logic, not TLS/authentication. Save schemas and production credentials were untouched.

## Remaining Gates

Synthetic controlled defeats prove result plumbing, not the probability of defeating each boss in natural play. No new full natural boss campaign, real online peers, physical iPhone gameplay, release Archive, signing, App Store upload or review submission was completed by this change. The earlier natural Colossus campaign remains evidence for its own source only.

This branch is stacked on PR 22 and is not merged into main or deployed to Railway. Whole-game balance, actual-device acceptance, durable adventure attempt receipts and complete release-source CI remain open.
