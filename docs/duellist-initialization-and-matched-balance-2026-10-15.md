# Duellist initialization and current balance evidence

Parent: `bfcb7c7`, feature/kras-online-random-rotation. Godot
4.7.1.stable.official.a13da4feb, isolated imported runtime and test saves.

## Verified initialization defect

DuellistBrain overrides GenericBrain.on_configured without calling its parent.
Consequently _tree remains null and _idle_phase remains zero: the shared
fallback has no pickup-tree access and all duel bots begin the idle circle at
the same phase instead of their seeded phase. This is an initialization defect,
not proof that it causes the character win-rate warning.

The one-line repair calls super.on_configured before retaining specialized
delayed damage tracking. No global character stats, physics, arena geometry,
scoring, reaction delay or acceptance thresholds changed.

Regression covers four difficulty levels, two seeds and four seats, checking
shared tree access, the same seeded phase as GenericBrain, retained damage
tracking and repeatability. Before: 4460 passed, 64 failed. After: all 4524
assertions passed; strict test log guard passed. Existing visibility, damage
delay and target-selection tests remain in that suite.

## Matched natural comparison

Both campaigns use tests/balance_contact_trace.tscn, --runs=112 --only=duel_pit
--seed-offset=101000000, --headless --fixed-fps 60, default arena, natural
authored 110-second maximum, pair-balanced roster schedule and four AI.
Each completed 112 baseline + 56 mirrored difficulty + two mutator/chaos
instances: 170 each, 340 total instances, not 340 independent samples.

All 112 baseline seeds and full roster arrays, and all 56 difficulty
seed/character/expert-seat assignments, were compared exactly. Each character
appears 56 times, 14 per seat; all 28 pairs co-appear 24 times. Both complete
170-record traces were verified and their baseline wins match their reports.
No source/test changes overlapped either campaign. Both terminal exits 0 and
strict runtime log guards passed. Host elapsed times: 468.1s and 690.8s, not
device FPS or an isolated performance comparison.

| Metric | Before | After |
| --- | ---: | ---: |
| Mean natural duration | 61.4621s | 63.9491s |
| Character bias | 0.125 | 0.1607143 |
| Seat bias | 0.0535714 | 0.0535714 |
| Expert placement-point share | 0.6487395 | 0.6543002 |
| Expert outright wins / 56 | 54 | 55 |
| Easy outright wins / 56 | 2 | 1 |
| Baseline tied matches | 0 | 0 |
| Flags | character advantage | character advantage |

Wins before -> after: Barq 4->9, Fanoos 22->15, Ghaim 7->9, Mowja 10->10,
Nabta 8->10, Ramla 9->11, Sakhra 24->32, Turs 28->16.
Seat wins: [29,34,19,30] -> [34,34,26,18]. Both mutator/chaos cases completed.

The initialization contract is repaired; balance is NOT accepted. Sakhra's
warning-bearing result became larger in this sample. The parent initialization
consumes an additional seeded RNG draw and changes fallback behavior, so later
realized inputs diverge even with matched configurations. This comparison
cannot isolate idle direction as the sole cause, and is not held-out acceptance
after examining the baseline. No warning was removed or threshold weakened.

## Current qualification and remaining scope

All 466 scripts compile; strict compile guard passed. Full suite passed 428109
assertions in 726.7s, exit 0; strict tests guard passed. Four ERROR entries were
checked individually: deliberate failed-save and three router-recovery cases.
No source/test edits overlapped full qualification.

Final content audit consumed the current matched report: BROKEN=0, READY=0,
NEEDS_BALANCE=39. Duel's evidence has no source/completeness issues but retains
character advantage. Other games lack accepted current-source balance evidence;
this classification does not mean all 39 have demonstrated gameplay defects.
Structural validity is not playability, physical touch QA or release approval.

Source fingerprints, stable at start/end of the respective campaigns:

- Before: `822cb23e2dafd2e0329ba9da190458f01ced0a0c9d527246710571804f458ee7`
- After/final full/audit: `cb22e0abe5d98a8cd2fe0d1ab315181712ace70b12bd5de0164bf60cdbc43a79`

Selected-source fingerprints exclude tests and many assets, and do not attest
a signed archive. Changed files were separately matched to the checkout:

- src/ai/brains/duellist_brain.gd: `5d841d0bc0155e607cb41e06963bab7a7e6c9f39e4c848b4428b826530d7e40a`
- tests/suites/test_ai_visibility.gd: `bfe2dd76073d6e5193c848a2a761ce8ff48191dc629a5b6c195876e0d3b69b69`

Full log SHA-256:
`13ecff1c6bd181e96f4d572e7f61b9ddd773338fb090375afe373bc1c3e50cde`.
Before/after report SHA-256:
`2239d1664f20fd83bfe451d29400e137e1a82f9f1d1cf23c7e0eb21354d3bae7`,
`53f32e6be947aa428814bf17a2171966e7332dcf046a5e05a84266624a4344ee`.
Sibling qualification-duellist-initialization-2026-10-15/ retains both reports,
HTML, original logs/progress, synthetic traces, comparison-audit.json, red/green,
compile/full and final content audit. No private player saves were copied.

Stage 0 stays QA_PENDING/MERGE_PENDING. Fairness/AI tactics, broader content
qualification, physical device and production backup/restore gates remain.
No new network campaign, main push/merge, deployment, native archive, upload or
Apple review submission. A physical-device availability question remains open.
