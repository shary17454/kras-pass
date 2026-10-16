# Independent Natural Balance Review

## Provenance

- Run: https://github.com/shary17454/kras-pass/actions/runs/37126402385
- Source: `d2f1c6af1e46dc578a2e501ec697e307d987a63a`.
- Seed offset: `100000`.
- The completed workflow has 41 successful jobs. All 39 natural-balance game artifacts were retrieved and validated against the source commit, run ID, catalogue, seed offset and paired difficulty schema.
- Aggregate: 39/39 games, 1638 matches, verified mirrored difficulty pairing, no missing game reports.
- Per-game evidence: the workflow's `natural-balance-<game>` artifacts.
- Local evidence: `/tmp/kras-independent-balance-37126402385-api` and `/tmp/kras-independent-balance-37126402385-summary.json`.

This source predates the round reward integrity and final-input boss dash clearance fixes. Do not attribute these campaign results to `5da88fbd664ca5987c7abcf649e1e5db21e4a6c9` or any later build.

## Open Balance Reviews

| Game | Review signal |
| --- | --- |
| bumper_bowl | Character advantage |
| duel_pit | Character advantage |
| duo_clash | Character advantage |
| goal_guard | Expert bots no better than easy |
| kart_sprint | Character advantage |
| ring_rumble | Spawn slot advantage |
| sabaq_sawarikh | Character advantage |
| scrap_karts | Spawn slot advantage; expert bots no better than easy |
| sky_court | Expert bots no better than easy |
| storm_heart | Expert bots no better than easy |
| zone_hold | Spawn slot advantage |

These are review signals, not established causal diagnoses. The 24 baseline matches per game are insufficient to justify changing character statistics solely from the observed winning percentages. Preserve thresholds and investigate mechanics, pairing, spawns and independent seeds before tuning.

## Selected Observations

- Goal Guard expert share: 0.519230769230769, below the existing 0.52 review threshold. A previously improved small sample did not establish general superiority across seeds.
- Ring Rumble baseline wins by slot: [3, 4, 5, 12]; slot bias 0.25.
- Zone Hold baseline wins by slot: [3, 3, 13, 5]; slot bias 0.291666666666667.
- Colossus average duration: 149.1 seconds against a 150-second window; tie rate 0.375; expert share 0.674698795180723. No existing balance flags were raised, but the report does not prove the boss was defeated. Match completion and boss victory are different requirements.

## Release Gate

`releaseReady` remains false. A successful campaign establishes execution and report completeness, not that all 39 games are READY. The flagged games require investigation, while unflagged games still need gameplay, device, input, camera and orientation qualification.

Required follow-up:

1. Diagnose slot advantage using mirrored spawn assignments and larger independent samples.
2. Diagnose expert difficulty on the four flagged modes without hidden speed, perfect information or impossible aiming.
3. Distinguish boss defeat from deadline completion in future qualification evidence.
4. Re-run affected games from the exact proposed release source after fixes.
5. Complete actual iPhone performance and gameplay testing before Archive, upload and review submission.

No balance thresholds, production rules, game durations, health or character stats were changed for this report. No App Store build was uploaded or submitted by this documentation step.
