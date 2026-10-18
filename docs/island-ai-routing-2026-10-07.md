# Island AI Routing Qualification

Base: 3ceca03b1380d6680b1942b829a46f9b225cd4b8.
Branch: fix/kras-island-ai-routing.

## Confirmed Defect and Implementation

Shared AI steering aimed directly at targets across internal island gaps.
The corrected bridges alone did not prevent those straight-line falls.

Arena now builds a native AStar3D graph once for the islands' public,
static floor layout. Shared AIBrain steering selects a reachable waypoint
when a straight approach crosses unsupported floor. The approach checks
floor support at intervals no greater than 0.2 metres. It skips waypoints
only when the shortcut is supported. The graph uses local coordinates;
queries convert world positions relative to the arena.

No opponent state, invisible pickup, private intent or network result is
read by routing. Existing perception, reaction delays, aim error, RNG,
speed, scoring and character statistics are unchanged. Other arena shapes
return the existing target unchanged. Dashes, attacks and knockback can
still cause falls; this is not invulnerability or perfect AI.

## Regression Evidence

Actual Fighter.tick movement with world collision, without jump or dash,
crosses from each satellite to a nonadjacent satellite for all eight
characters on both maps: 80 routes. Other fighters' collision layers are
disabled only in this fixture to isolate routing from combat.

- Before routing: 1156 assertions passed, 65 failed.
- After routing: all 1221 collection/network assertions passed.
- Repeat after moving the arena to (30, 5, -20): all 1221 passed.
- Existing AI visibility/perception suite: all 3927 assertions passed.
- Compile check: all 396 scripts compile.
- Platform ground-routing regressions: all 41 assertions passed after
  guarding arenas without a built definition/navigation graph.
- Runtime/test log guards and git diff --check passed.
- Existing macOS CA-access diagnostic remains an environment limitation.

Logs: /tmp/kras-island-routing-red2.log,
/tmp/kras-island-routing-green.log,
/tmp/kras-island-routing-translated.log,
/tmp/kras-island-routing-visibility.log,
/tmp/kras-island-routing-compile.log.

## Matched Natural Comparison

Unchanged seed offset 900000 and validation thresholds; both versions ran
24 baseline matches, 16 paired character/difficulty samples and mutated/
chaos smoke matches to natural completion.

| Metric | Bridges only | Routing added |
| --- | ---: | ---: |
| Expert edge | 0.51123595505618 | 0.593406593406593 |
| Slot bias | 0.25 | 0.125 |
| Character bias | 0.125 | 0.0833333333333333 |
| Mean paired falls per player | 20.625 | 6.5 |
| Mean baseline duration, seconds | 88.76875 | 91.270139 |

Before: spawn-slot and weak-Expert flags. After: no flags in this sample.
This is not universal balance qualification or proof that falls vanished.
The final source after the null-definition guard repeated all 42 natural
matches with the same metrics and no balance flags. Committed reports:
docs/island-ai-routing-baseline-report.json and
docs/island-ai-routing-natural-report.json.
Final log: /tmp/kras-island-routing-final-natural.log; runtime guard passed.
Final source fingerprint before and after was identical:
ed3aee3023792240e143d92ecb748f13ed180f0e306958218928f1a575a6df34.

## Remaining Gates

The first full gate failed: 369900 assertions passed and three platform
assertions failed, with null-definition script errors. The root cause was
the new routing query reading an unbuilt arena's definition. The guard
preserves ordinary steering when no static island graph is available.
The final full gate completed successfully (exit 0): all 369903 assertions
passed, the actual three-lap race passed, all six boss regressions passed,
and all 39 stability matches passed with zero failures. Inventory: 489
resources, 22 autoloads, 27 routes, eight characters and zero issues.
Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.GhNI4M.
The stability fixture intentionally emits a memory-warning signal; its
short cache-release check is not a long-session/device memory-leak proof.
Additional seed campaigns,
physical device performance/thermal/battery QA, production rollout,
Distribution archive, upload and Apple review submission remain required.
No main merge or production deployment is part of this branch.
