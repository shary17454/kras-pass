# Boss weakpoint attack input qualification

Runtime/direct-fixture commit: `739fd55c93cea37eeee2e35974acb218b0bae0f8`.
Frozen source with perception fixture correction:
`43b68a172809dc720421440a878b484e9ebf4b14`.
Branch: `fix/kras-boss-weakpoint-tap-actions`.
Parent: `b624f29649eba22864b62aa0f22d6a0dfff14196` (PR 192).
No main merge, production deployment or Apple archive/upload/submission.

## Defect and scope

The generic BossHunter weakpoint request held ATTACK across eligible decisions.
Fighter only starts an attack on a new input edge. At a continuously reachable
Dreadnought vent, this can suppress later swings after cooldown expiry.
Only the generic weakpoint branch now uses the existing tap helper. The
Colossus attack-plan branch and Forge feeding-plan branch retain their existing
behavior; no health, damage, hit arc/range, cooldown, RNG draw count, attack
probability, perception delay, movement, hazards or balance threshold changed.
The shared weakpoint branch serves Dreadnought and Sovereign.

The actual stationary Dreadnought fixture uses BossHunter, InputRouter, Fighter
timers/button handling and the controller's real vent damage/cooldown handler.
Movement, boss turning and hazards are isolated; reaction/noise/mistakes are
zero and attack probability is one only in this fixture. It does not qualify
natural tactical behavior or complete boss matches. In all four tiers it
requires repeated edges and at least a second actual vent hit, preserves the
vent cooldown limit, matches damage to credited score and checks release.
Additional guards preserve attack probability, hidden-target rejection,
target-acquisition delay and reach.

## Focused checks and retained failures

- The first command used the wrong suite filter and selected no suites:
  `/tmp/kras-boss-weakpoint-red.log`, exit 1. This is not defect evidence.
- Correct pre-fix red: 130 passed, 12 failed across four tiers, exit 1;
  `/tmp/kras-boss-weakpoint-red-selected.log`.
- First green: 142 passed in 17.9 seconds, strict log check passed;
  `/tmp/kras-boss-weakpoint-green.log`.
- Expanded guards: 158 passed in 25.9 seconds, strict log check passed;
  `/tmp/kras-boss-weakpoint-guards.log`.
- Existing weakpoint perception tests initially failed two assertions reading
  `brain.bits` (53 passed, two failed); `/tmp/kras-boss-weakpoint-perception.log`.
  That variable intentionally excludes one-shot requests. The fixture now
  publishes through the actual InputRouter and checks the observed press edge
  and hidden-target output, retaining every visibility/delay assertion.
  Corrected: 55 passed in 3.8 seconds, strict log check passed;
  `/tmp/kras-boss-weakpoint-perception-frames.log`.

## Exact-source full gate

The full gate on frozen source 43b68a1 completed with exit 0:
`/tmp/kras-party-check.JrqqS0`.
420 scripts compile; 519 resources, 22 autoloads, 27 routes, eight characters
and zero inventory issues. 390211 assertions passed in 416.2 seconds.
Actual three-lap race, six boss regressions and one 39-game stability cycle
passed; stability failures: zero. Every stage strict Godot log guard passed.
The deliberate memory-warning fixture drained caches; it is not a phone
warning, a long soak or proof of absent memory leaks. Negative save/router
error-path logs are deliberately retained by their tests.

Dreadnought seed 9614, Expert: defeated, health zero, scores
`[315,270,270,245]`. Sovereign seed 9614, Expert: defeated, health zero,
scores `[270,450,480,300]`. These complete-fight regressions do not constitute
paired all-tier balance samples or qualify every seed.
Fresh server tests used all six real world captures from this exact gate:
204 passed, zero failed/cancelled/skipped/todo, 927.808917 ms;
`/tmp/kras-boss-weakpoint-server-tests.log`.
The runtime and test files remained identical to 43b68a1 during qualification.

## Qualification not yet established

The full regression gate is not natural balance, online or physical-device
qualification. The parent all-game campaign 37659174645 is
on 8805873 and cannot certify this changed runtime. Its results must not be
substituted for current-source acceptance.
Full product acceptance, current all-game balance/perception and polish,
physical iPhone/iPad FPS/thermal/energy QA, approved production promotion and
backup/migration, production Internet/auth acceptance, new Version/Build,
local Xcode 27 Distribution archive and separately verified upload/processing/
review submission remain open. No Xcode Cloud or P12 import is permitted.
