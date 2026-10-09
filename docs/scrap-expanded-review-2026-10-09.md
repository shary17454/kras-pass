# Scrap Expanded Balance Review

Source: `2b403d8`, on `feature/kras-online-random-rotation`.
Both reports and an independent checkout calculation agree on fingerprint
`63751e709a6ee8d4239a8c2ca0d5bf8a1aa7f999019f33477888aa77a8b5d644`.
Engine: local Godot 4.7.1. No gameplay or acceptance threshold changed.

## New Natural Samples

Commands used `tools/balance_sim.tscn`, `--headless --fixed-fps 60`,
`--only=scrap_karts --balanced-rosters`, isolated test storage and report
directories outside the project and player saves. No clipped rounds.

| Seed offset | Baseline | Difficulty matches | Stress | Expert share | Ties | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 6800000 | 64 | 32 | 2 | 0.525994 | 0.03125 | none |
| 7100000 | 256 | 128 | 2 | 0.556322 | 0.03125 | none |

Total new completed matches: 484. Both processes exited zero and passed
the strict runtime log checker. Both mutated and chaos checks passed.
Independent Node assertions checked stable source fingerprints, each
baseline seed formula, completed difficulty samples, matched seeds and
characters, and mirrored Expert slots for all 16 and 64 pairs respectively.
The two baseline seed ranges do not overlap.

Baseline slot wins (including shared winners): first `[14,21,11,20]`,
second `[58,80,73,53]`. Baseline character wins in the larger sample:
barq 36, fanoos 24, ghaim 41, mowja 31, nabta 36, ramla 28,
sakhra 30, turs 38. This is natural outcome evidence, not physical-device
QA, statistical proof of fairness or final balance acceptance.

The earlier 24-baseline campaign warning remains in history. Larger
unflagged samples do not retroactively erase it, and Expert share is a
placement-point metric rather than a win probability. The current evidence
does not justify retrying the previously rejected facing-backoff or
ram-alignment policies. No character, physics, AI profile or damage
parameter was adjusted merely to clear a report.

## Campaign Observation

Downloaded reports from run 37915371500 at
`b61e4b44894e12ad05f14981d3a1686efa2e058b` were checked with
`tools/balance-report.mjs --partial --paired --seed-offset=6800000`
and their own `c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`
fingerprint. The observation contains 30/39 games and 1260 matches;
the strict partial validator exited zero, while `complete`,
`sourceConsistencyVerified`, `balanceReviewComplete` and `releaseReady`
remain false. Do not attribute this older campaign to current source.

Warnings requiring review:
- rising_tide: ties in 11/24 baseline matches (45.8333%).
- scrap_karts: Expert no better than Easy in the smaller campaign sample.
- sweeper_storm: character advantage and Expert no better than Easy;
  sakhra won 11/24 baseline matches, Expert share 0.50625.
- turret_duel: spawn slot advantage on the pre-heading-fix source.

Missing at download: boss_colossus, boss_dreadnought, boss_sovereign,
sabaq_sawarikh, relic_hold, tag_hunt, base_siege, drift_floes, duo_clash.
The live campaign was not cancelled or restarted.

## Evidence and Next Work

Local reports:
`/tmp/kras-scrap-2b403d8-expanded-report/report.json`,
`/tmp/kras-scrap-2b403d8-independent-report/report.json`.
Logs: corresponding `/tmp/kras-scrap-2b403d8-{expanded,independent}.stdout`.
Campaign download: `/tmp/kras-b61-balance-37915371500-observation-three/`.
Preserved local reports and logs:
`../qualification-scrap-expanded-2026-10-09/`.

Next: diagnose whether rising_tide ties follow simultaneous elimination,
survivors at timeout or the shared sudden-death path; then examine
sweeper_storm character/hazard interaction on current source. Preserve
natural comparisons and do not introduce unfair AI information or
slot-order tie winners. All-game and real-device gates remain open.
No main merge, push, production access, archive, upload or review submission.
