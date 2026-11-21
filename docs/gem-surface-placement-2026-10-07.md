# Gem Surface Placement Qualification

Base: 29431b415dc968aeecd01779150ef77b020ea54f.
Branch: fix/kras-gem-ground-placement.

## Confirmed Defect and Scope

Gem Grab used the arena origin plus 1.1 for every gem destination, even
when the supporting island floor had a different height. Its ground ray
checked presence but discarded the actual surface position. A gem could
therefore be hidden below the highest island floor.

The fix returns the actual collision surface plus 1.1. Candidate X/Z,
seeded random calls, attempt limits, collision mask and the initial
central fallback are unchanged. No scoring, AI, network schema or match
duration changes are included.

## Regression Evidence

Actual physics colliders in both gem_hollow and glass_terrace were tested
after translating the arena by (30, 5, -20). Each arena sampled 120
destinations, including the highest satellite island.

- Before fix: 697 assertions passed, 124 failed.
- After fix: all 821 collection/network assertions passed.
- Strict Godot log guard and git diff --check passed.
- Logs: /tmp/kras-gem-ground-red.log and /tmp/kras-gem-ground-green.log.

## Natural Simulation

Godot 4.7.1, seed offset 300000, natural match completion:

- 24 baseline matches completed; mean duration 87.518 seconds.
- 16 paired character/difficulty samples completed.
- Mutated and chaos smoke matches completed.
- Expert edge 0.546512; slot bias 0.173077; character bias 0.067308.
- No validator balance flags in this sample; no zero-score matches.
- Source fingerprint before and after was identical:
  60d5d4a006f60a392379c82a5731ab4fbc949f174c434955345c35092c240165.
- Report: /tmp/kras-gem-ground-natural-report/report.json.
- Log: /tmp/kras-gem-ground-natural.log; strict log guard passed.

## Remaining Gates

One sample is not proof of robust balance. Frequent AI falls remain
observable; island routing, bridge steps and dropped-gem placement over
gaps are not addressed here. Initial placement before physics registration
still uses the existing fallback. This branch has not received the full
release gate, physical iPhone QA, Distribution archive, upload or Apple
review submission.

Separately, the unchanged integration base 29431b4 passed its full
tools/check_party.sh gate: 368781 assertions, actual three-lap race,
six boss regressions and 39 stability matches with zero failures.
Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.Fz9Zty.
Those results do not qualify this later runtime change.
