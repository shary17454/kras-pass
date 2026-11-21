# Completed all-game natural balance campaign

Run [37939933912](https://github.com/shary17454/kras-pass/actions/runs/37939933912)
completed successfully. Captured source 76813931a747040469036e44e4e7de0d386ee109,
simulation fingerprint a33587770b6fbe8bc48988c0b8f0ad0a41c3e96337d8be9eb418787e23661959,
Godot 4.7.1, seed offset 8000000.

Downloaded every artifact and independently ran tools/balance-report.mjs with
the captured commit, run, fingerprint and paired seed policy. Local summary
deep-matches CI summary. All 117 import/policy/simulation logs passed strict
checks in their corresponding modes. Coverage: 39 of 39 games, 1638 completed
natural matches (24 baseline +16 paired difficulty +2 stress per game),
source consistency and matched seed/character difficulty pairing verified.

## Review findings retained

| Game | Finding |
|---|---|
| boss_colossus | character advantage |
| boss_sovereign | spawn slot advantage |
| crumble_court | expert bots no better than easy |
| goal_guard | expert bots no better than easy |
| magnet_court | expert bots no better than easy |
| star_rush | character advantage |
| turret_duel | spawn slot advantage |

balanceReviewComplete=false and releaseReady=false. These are review signals
from limited samples, not proof of crashes or permission to blindly retune
stats. Prior independent/expanded warnings are not erased because other
games have no flags in this seed cohort. The original complete product scope
and physical device acceptance remain open.

Boss baseline outcomes: Colossus 17 defeated/7 survived, Dreadnought 24/0,
Forge 24/0, Sovereign 22/2, no unknown outcome. All 16 paired difficulty
matches per boss defeated it; both stress scenarios per boss survived.
Defeat/survival are outcome evidence, not an automatic quality score.

Evidence: ../qualification-balance-768-complete-2026-10-09/ contains all raw
artifacts, original CI summary and independently verified-summary.json.

The later Forge visibility-only collar changes the full source fingerprint
to 53cde46b50cf16a86a63439072b716dfbf475238dfca1ef42a671d5bc384b552.
This completed campaign is not relabelled as that source. Its current-source
Core check passed separately, but full natural balance evidence for that
fingerprint still requires a fresh campaign. No main merge, Railway mutation,
App Store upload, submission or new stage DONE is claimed here.
