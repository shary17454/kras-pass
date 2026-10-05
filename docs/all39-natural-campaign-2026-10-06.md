# Full Natural Campaign Qualification

## Source And Coverage

Frozen checkout: `/tmp/kras-impact-publish`, commit
`e2545d48aa9e77aca70a9853541a6f0955bd3fa6`.
Its tracked tree equals integrated main `cb692323bd44214dde54a74a036078e1a457300e`.
The source remained unchanged through the campaign (`git diff --exit-code`).
This is NOT the subsequently integrated `734f08d` platform-routing source or
the later warning-jump change.

Godot 4.7.1 official, macOS, headless, fixed simulation 60 Hz.
Command: `tools/balance_sim.tscn --runs=24 --seed-offset=600000` with isolated
`--test-data-dir=/tmp/kras-effective-all39-save` and output directory
`/tmp/kras-effective-all39-report`.
Natural authored round windows were retained; races used the existing true
three-lap finish and safety guard. No ordinary short smoke window was used.

The original process completed with exit 0 after 5343.5 wall-clock seconds.
The runtime log guard passed. `tools/balance-report.mjs` validated all 39
catalogue IDs, all eight characters' mirrored difficulty pairs, baseline seed
sequence, 24 completed baselines, 16 completed difficulty matches and two
mutator/chaos matches per game: **1638 completed matches**, no missing games.
The validator received per-game views of the combined local report and the
explicitly verified checkout identity; this was not a GitHub artifact receipt.

Evidence:

- `/tmp/kras-effective-all39-report/report.json`
- `/tmp/kras-effective-all39-report/report.html`
- `/tmp/kras-effective-all39.log`
- `/tmp/kras-effective-all39-engine.log`
- `/tmp/kras-effective-all39-save/balance_progress.txt`

## Findings

Seven games triggered automated balance review. Expert place-share below 0.5
is not evidence of an Expert advantage; character/spawn bias is a limited
sample signal, not a conclusive statistical diagnosis.

| Game | Mean Seconds | Expert Share | Automated Finding |
| --- | ---: | ---: | --- |
| tank_arena | 96.589 | 0.5875 | none |
| ring_rumble | 40.964 | 0.5625 | none |
| crumble_court | 5.992 | 0.6000 | none; round pacing needs polish |
| bumper_bowl | 86.270 | 0.6832 | none |
| fawda | 44.160 | 0.6062 | none |
| goal_guard | 33.014 | 0.5337 | none |
| magnet_court | 37.045 | 0.5337 | none |
| storm_heart | 28.990 | 0.5288 | none |
| sky_court | 33.933 | 0.5337 | none |
| blast_ball | 25.083 | 0.4688 | Expert no better than Easy |
| scrap_karts | 16.663 | 0.4691 | Expert no better than Easy |
| turret_duel | 101.270 | 0.6747 | none |
| gem_grab | 93.772 | 0.5385 | none |
| star_rush | 90.017 | 0.6894 | none |
| paint_grid | 80.017 | 0.6957 | none |
| mnatiq | 97.518 | 0.6957 | none |
| mukharrib | 95.017 | 0.6750 | none |
| zone_hold | 100.022 | 0.6627 | none |
| crate_smash | 75.017 | 0.6957 | none |
| lab_crates | 91.267 | 0.6957 | none |
| crate_relay | 95.022 | 0.6957 | none |
| hurdle_dash | 11.713 | 0.6813 | none; round pacing needs polish |
| kart_sprint | 35.475 | 0.7000 | none |
| color_stand | 30.211 | 0.7193 | none |
| symbol_echo | 95.017 | 0.7019 | none |
| quick_draw | 75.017 | 0.6957 | none |
| rising_tide | 12.293 | 0.5341 | none; round pacing needs polish |
| sweeper_storm | 28.857 | 0.5875 | character advantage (bias 0.25) |
| duel_pit | 68.761 | 0.6481 | spawn advantage (bias 0.25) |
| boss_forge | 61.985 | 0.6667 | none |
| boss_colossus | 150.000 | 0.6667 | no baseline boss defeat |
| boss_dreadnought | 13.354 | 0.7037 | none; round pacing needs polish |
| boss_sovereign | 70.421 | 0.6667 | none |
| sabaq_sawarikh | 131.073 | 0.7000 | character advantage (bias 0.25) |
| relic_hold | 95.017 | 0.6319 | none |
| tag_hunt | 90.017 | 0.4540 | Expert no better than Easy |
| base_siege | 79.644 | 0.5679 | none |
| drift_floes | 39.728 | 0.5455 | none |
| duo_clash | 49.501 | 0.5614 | none |

For this campaign's internal audit, the seven flagged games are
`NEEDS_BALANCE`; the remaining games remain `NEEDS_POLISH` pending actual
human play, orientation and device QA. No game is promoted to `READY` merely
because its automated flags are empty. This classification is evidence-based
review state, not a change to the runtime game catalogue.

## Boss Objectives

Actual baseline boss defeats: Forge 24/24, Colossus 0/24, Dreadnought 24/24,
Sovereign 21/24. All four bosses were defeated in all 16 mirrored difficulty
matches per boss. Each boss survived both mutator and chaos samples.
The latter samples completed without invalid lifecycle states but did NOT
prove boss victory. Points at the deadline are not treated as boss defeats.
Colossus Medium baseline and mutator/chaos boss objectives need investigation.

## Release Limits

This is simulated match evidence, not measured phone FPS, thermal/battery
qualification, 39-game rendered QA, Internet multiplayer, authentic player
enjoyment or an Apple Distribution archive. It does not prove all product
requirements complete. Balance review and release readiness remain false.
The subsequent platform-routing and warning-jump changes require their own
source-specific checks; the historical campaign must not be relabelled.
