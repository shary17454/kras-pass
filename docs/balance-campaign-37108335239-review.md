# Completed Natural Balance Campaign Review

Run: https://github.com/shary17454/kras-pass/actions/runs/37108335239
Exact source: `0b21cac95075705a3ee85641e33e3aa680bcd879`.

All 39 simulation jobs finished successfully. Downloaded reports under
`/tmp/kras-balance-37108335239-complete-retry` passed the full source/run/checkout
and coverage validator. Aggregate: `/tmp/kras-balance-37108335239-summary.json`.
There are 1,482 completed matches, no missing games and no critical report flags.
The first download failed with HTTP 401 for one artifact; one retry succeeded.
No credentials were changed or printed.

## Findings And Follow-Up

Sixteen games have review flags. They remain unresolved screening signals:

- High draw rates: boss_colossus (54%), duo_clash (42%). Inspect actual result
  rules and contribution scores, including team semantics, before changing them.
  Do not arbitrarily select a winner just to suppress a warning.
- Character advantage: duel_pit, mnatiq, ring_rumble, sabaq_sawarikh,
  sweeper_storm. Validate exposure-normalized per-game outcomes with more samples
  and several arenas before changing global character stats.
- Spawn advantage: tank_arena. Visible ammo selection is independently fixed
  by source `07d81f7`, but this does not prove the spawn flag is resolved.
- Expert not better than Easy: drift_floes, fawda, goal_guard, magnet_court,
  scrap_karts, storm_heart, sweeper_storm, tag_hunt, zone_hold. These comparisons
  use the old unpaired seeds/characters, so they cannot isolate difficulty.
  Re-run the current matched seed/character/seat policy before retuning AI.

The original reports are complete execution evidence, not balanced-game or
release evidence. `difficultyPairingVerified`, `balanceReviewComplete` and
`releaseReady` are false. Raw aggregate character win counts are not normalized
win rates. This campaign predates the subsequent relic/tag observation changes,
matched difficulty policy and tank-ammo fix.

## Next Gate

Run a new campaign from the current immutable feature commit, with 24 baseline,
16 paired difficulty and two smoke matches per game: 1,638 planned matches.
Retain the original campaign rather than cancelling, overwriting or relabelling
its evidence. Full regression/network checks, device QA, Railway release sync,
archive/signature validation and App Store submission remain separate gates.
