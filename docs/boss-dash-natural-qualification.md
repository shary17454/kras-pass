# Final-Input Boss Dash Qualification

Source: `5da88fbd664ca5987c7abcf649e1e5db21e4a6c9`.

The test runtime's 718 tracked inputs were byte-compared with this source before the campaign; no mismatches. This is a mirrored headless test checkout, not a signed release Archive.

## Regression

The guard evaluates the full five-meter projected dash segment after final noisy input. It follows drive/neutral-stick facing and the player's own speed modifier. Hole-crossing dashes are removed without removing attack, while clear-ground dashes remain available. No new random draws, hidden buffs, health changes or shortened production rounds were introduced.

- Corrected pre-fix fixture: 109 passed, three dash assertions failed.
- Fixed fixture: 112 passed.
- Shared AI visibility suite: 135 passed.
- Compile: 324 scripts passed.
- An earlier fixture placement reset ground before unrelated target checks; those contaminated results are not production regressions and are not the baseline above.

Logs: `/tmp/kras-boss-dash-baseline-isolated.log`, `/tmp/kras-boss-dash-final.log`, `/tmp/kras-boss-dash-ai-regression.log`, `/tmp/kras-boss-dash-compile.log`.

## Natural Campaign

Command: Godot 4.7.1 headless, fixed-fps 60, `tools/balance_sim.tscn -- --only=boss_colossus --runs=24 --seed-offset=100000`. No clipped mode. Completed successfully after 4646.5 seconds wall time on the shared Mac.

- 24/24 baseline rounds, production window 150 seconds.
- 16/16 mirrored difficulty rounds, eight characters.
- Mutator and chaos smoke both passed: 42 matches total.
- Mean baseline duration 147.1722 seconds.
- Tie rate 0.3333333.
- Expert share 0.6627219.
- Slot bias 0.04411765; character bias 0.02205882.
- Baseline wins by slot: [8, 8, 10, 8].
- Existing report flags: none. Thresholds unchanged.

Raw report: `boss-dash-natural-5da88fb.json`; log `/tmp/kras-boss-dash-natural.log`.

The prior independent D2 campaign at the same offset reported mean 149.1 seconds, tie rate 0.375 and expert share 0.6746988. This comparison is descriptive, not statistical proof or isolation of every source change. The completed report still does not separately establish boss defeat rather than deadline completion, full physical trajectory safety, actual device performance or live online peer qualification.

## Production Observation

Railway deployment `964d5a83-9758-486a-8a19-ecb1ae4da28a` was SUCCESS, linked to `shary17454/kras-pass`, `main`, full source hash above. Created 2026-10-03T15:18:28.750Z. No duplicate deployment was created.

Bounded logs: 40 build records and six deployment records, zero matching error/fatal/failed/uncaught records. Production `/health` returned ok=true and authentication_ready=true; multiplayer_enabled=false. These checks are not real-device authentication, database integrity for the new deployment, sustained monitoring or all API acceptance.

No Archive, signing, App Store upload, processing or review submission took place. Outstanding full-content balance and real-device acceptance gates remain open.
