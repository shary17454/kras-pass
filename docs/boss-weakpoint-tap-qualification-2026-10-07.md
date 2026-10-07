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

## Natural balance on the frozen runtime

Both samples completed on `193826b5c1aa778754ee762508dfa830b4324cb5`,
whose runtime and test files are identical to 43b68a1. Each includes 24 natural
baseline matches, 16 matched-seed/character difficulty matches and two stress
checks: 84 matches total. Independent validation confirmed all eight difficulty
pairs and identical start/end hashes for 272 source files. Fingerprint:
`17ed23ad30959bf5285ae4fda9ce7d5954de44f17675a3c04d997d3212c2cc08`.
Both processes exited zero and passed their strict log guards. Seed offset:
1200000; no balance thresholds, seeds or authored rules were changed.

| Game | Expert share | Character bias | Seat bias | Baseline ties |
| --- | --- | --- | --- | --- |
| Dreadnought | 0.690909 | 0.150862 | 0.060345 | 0.208333 |
| Sovereign | 0.690909 | 0.035000 | 0.070000 | 0.041667 |

No automatic balance warnings were produced. In each game the boss was defeated
in all 24 baseline and 16 difficulty matches. Both mutated/chaos stress bosses
survived; successful execution is not a boss-defeat claim. The baseline ties
are retained, not treated as missing winners. These two samples do not establish
all-game balance review or release readiness; the validator reports both false.
Raw reports: `docs/qa/boss-weakpoint-tap-2026-10-07/`.
Logs: `/tmp/kras-weakpoint-boss_dreadnought-1200000.log` and
`/tmp/kras-weakpoint-boss_sovereign-1200000.log`.

## Current-runtime four-client Dreadnought network check

Four real Godot processes and a local WebSocket service completed the authored
boss match with scripted human inputs, seed 309004. Host and one guest resumed
their sessions; all clients agreed on scores `[605,540,515,540]`. Guests received
901/901/882 world snapshots. The fixture requires real damage, shells and boss
defeat, and rejects guest-side authoritative simulation or divergent health.
The process exited zero; all four client stdout files passed strict log guards.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-VVlTzI`.
Maximum server event-loop delay: 78 ms. Cumulative client maximum frame gaps:
1753/1725/1780/1797 ms, including startup/transitions. Their cause and steady-state
frame times are not qualified. This is not Internet, physical-player, mobile
FPS, battery or thermal evidence. Full client logs are not committed because
they may contain temporary reconnection credentials.

Sovereign also passed with four real clients, the same frozen runtime and seed
309004. Authored boss duration was retained. All clients agreed on scores
`[960,840,720,480]`; host and one guest resumed. Guests received 2329/2310/2329
world snapshots. The fixture requires damage, orb return, shield and defeat,
and rejects guest-side authoritative objects or divergent health. Exit zero
and all four strict stdout guards passed. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-QMLsel`.
Maximum server event-loop delay was 139 ms. Cumulative maximum client frame
gaps were 2752/2763/2770/2785 ms, including startup/transitions; this does not
establish steady 60 FPS. Both network runs are single local matches, not
tournament-final, public Internet, adverse-network or physical-device coverage.

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
