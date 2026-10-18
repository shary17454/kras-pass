# Natural balance review, seed cohort 4200000

GitHub run 37813002835 completed successfully on source commit
78d11abdb35144a6c754414487606093dd5c1435, official Godot 4.7.1.
The independent report verifier confirmed all 39 games, 1638 completed matches,
matched-seed/character difficulty pairs and a stable source fingerprint
b90edfc4d8fb5f0b42fa8063f41e564f252a0c9f40ea09e2f3e2db1fa990d553.
All 117 import/policy/simulation logs passed their strict log guards.

Warnings remain: Blast Ball expert/easy edge 0.48125; Sweeper Storm character
bias 0.25 (Sakhra 9/24 wins); Gem Grab slot bias 0.23; Zone Hold slot bias 0.25;
Duo Clash individual first-place ties 50%.

Two independent local natural samples on current commit
279c06dd2e4b4faac97a6cca12b88e40c0871c4d used seed offset 4300000.
Their start/end fingerprint matched
8fb698a7f79cb597d0381ee3e2262b5b5b079eb5c3013ac512ff061639377d85.
Each completed 24 baseline matches, 16 mirrored difficulty matches and two
mutator/chaos matches, with strict runtime logs passing.

| Game | 4200000 slot wins | 4300000 slot wins | New slot bias | New flags |
| --- | --- | --- | --- | --- |
| Gem Grab | 6,2,5,12 | 11,6,6,5 | 0.142857 | none |
| Zone Hold | 1,5,6,12 | 7,3,5,9 | 0.125 | none |

Gem Grab's strongest slot changes between samples. Zone Hold still has its
largest count in slot four, but the second sample is below the unchanged alert
threshold. This does not prove universal spawn fairness. The source and seeds
both differ, so these comparisons are not a controlled causal experiment.
Do not alter spawn rules or suppress warnings solely to make these samples green.

Duo Clash needs a semantic review: MatchResult.is_draw counts multiple first
places, while this game encodes team totals plus individual KO contribution.
A same-team first-place tie is not evidence of a tie between opposing teams.
The raw warning is preserved; no scoring/threshold change was made here.

Boss baseline outcomes: Colossus defeated 18/24, Dreadnought 24/24,
Forge 24/24, Sovereign 23/24. All mirrored boss matches defeated the boss;
both stress variants for every boss survived rather than defeated it.
Thus stress completion is not stress victory evidence.

Retained raw campaign evidence: ../qualification-4200000-expanded/.
Machine summaries and current-source local reports: qa/balance-4200000-complete/.
This older-source full campaign is not final-source qualification, nor Apple,
physical-device, production or App Review acceptance.
