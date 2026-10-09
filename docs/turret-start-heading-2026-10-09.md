# Turret Start Heading Qualification

Base source: 9d528df. Campaign 37915371500 at b61e4b4 had 14 completed
game reports (588 natural matches) at this observation. Its qualified
partial reports raised `spawn slot advantage` for turret_duel and
`expert bots no better than easy` for scrap_karts. The latter is still open.
The all-game campaign remains incomplete and is not release acceptance.

## Confirmed Heading Defect

Turret vehicles inherited the same world-forward heading regardless of
their position on the spawn ring. One seat faced inward, one outward,
and two sideways. `on_round_start()` now faces each valid fighter toward
the arena centre using the existing `face_direction()` helper, which
also synchronizes drive steering. Cooldowns, damage, speed, scoring,
projectiles, character stats, and the arena recipe are unchanged.
The actual match lifecycle calls this before AI round-start decisions.

The new two-round/four-seat fixture checks facing and drive yaw after
reset. RED: 62 passes, 12 failures, exit 1. GREEN: 74 passes, exit 0.
Existing projectile cleanup and protected-hit cases remain in that suite.
Turret network-state suite: 70 passes. All 442 scripts compiled.
Green logs individually passed the strict Godot log checker.

## Natural Before/After Comparison

Same local Godot 4.7.1 platform, seed offset 6800000, 64 baseline matches,
16 paired difficulty matches, two stress matches per run: 82 matches
before and 82 after. Independent comparison verified identical baseline
seed and character-roster arrays. No clipped rounds or forced scores.

Before fingerprint:
`c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`.
After fingerprint:
`63751e709a6ee8d4239a8c2ca0d5bf8a1aa7f999019f33477888aa77a8b5d644`.
Both reports' start/end fingerprints agree; the after fingerprint was
independently recomputed from the checkout.

| Measure | Before | After |
|---|---|---|
| Slot wins, including shared winners | [10,16,28,17] | [18,16,23,13] |
| Flags | spawn slot advantage | none |
| Expert edge | 0.6443 | 0.6617 |
| Tie rate | 0.078125 | 0.078125 |
| Average duration, seconds | 102.052 | 103.459 |
| Mutator and chaos smoke | both pass | both pass |

This supports retaining the inward-heading fix. One matched cohort does
not establish complete spawn/character fairness or all-arena balance.
Full current-source regression and actual multi-peer turret matches
remain required. Existing CI runs retain b61e4b4 and do not certify the
changed shipping code. No main merge, deploy, archive or submission.

Raw evidence roots:
`/tmp/kras-turret-6800000-expanded-report/`,
`/tmp/kras-turret-heading-6800000-candidate-report/`, their stdout logs,
and `/tmp/kras-turret-heading-{red,green,network,compile}.stdout`.
Preserved copies: `../qualification-turret-heading-2026-10-09/`.
