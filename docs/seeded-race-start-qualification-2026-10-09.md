# Seeded race starts: current-source qualification

## Source and scope

Shipping source: db231a836441e67b895f75ff2800049f04cd4818,
branch `feature/kras-online-random-rotation`. This qualification adds test
evidence and assertions, not character-stat, AI, physics or rule changes.
Simulation source fingerprint before, after and independently recomputed:
`4a828a1cc9142dca43b62b3873e60a701d919696bb826e2e0b936435d3141140`.

The new network observer records seed, arena and the four assigned starting
vectors for every racing round. The JavaScript verifier rejects absent,
divergent, duplicate or invalid evidence. All four peers must agree; a matching
final score alone is no longer sufficient for this check.

## Verified checks

- Five verifier unit tests passed, including negative fixtures.
- Server suite: 260 passed, 6 skipped, 0 failed. Skips are not acceptance proof.
- Godot: all 442 scripts compiled; strict log check passed.
- Actual local WebSocket service and four Godot processes completed
  `sabaq_sawarikh`, seed 6009614. Every peer reported identical start allocation
  and scores `[18935,18175,18741,18884]`. Host and one guest reconnected. Exit 0.
  These are scripted inputs, not four people or production Internet QA.
- Natural balance campaign: 120 baseline matches, 60 paired difficulty matches,
  and two mutator/chaos matches completed. No clipped rounds. Seed offset
  6000000; baseline seeds and rosters independently matched the preceding
  equal-depth campaign. Source remained unchanged. Exit 0 in 1275.8 seconds;
  strict log check passed.

## Balance remains incomplete

| Metric | Previous equal-depth grid | Seeded lane allocation |
| --- | --- | --- |
| Slot wins | 32,20,42,26 | 29,31,40,20 |
| Warning flags | spawn slot advantage; character advantage | character advantage |

Current character wins: barq 36, nabta 24, fanoos 15, ghaim 14, mowja 10,
sakhra 8, turs 7, ramla 6. Tie rate 0, average simulated duration 129.52
seconds, Expert edge 0.70. Mutator and chaos passes succeeded.

The absent slot warning in this sample is not proof that every lane, map or
seed is equally favorable. Character advantage remains an explicit release
issue. No thresholds were relaxed, roster policy changed or warnings hidden.
This is one game, not a current-source qualification of all 39 games.

## Other gates

Remote full-network run 37890891082, source
19f21be72a518936c7c0a9b13711fd2d680d255a, is now terminal failure:
38 game-network jobs succeeded and `network-tank_arena` failed. The known tank
failure lacked observed armor damage despite shot/inventory evidence.
The local race pass does not resolve that failure or establish current-source
all-game network readiness.

No main merge, production database migration, Railway deployment, physical
iPhone/iPad acceptance, new Xcode archive, upload or App Review submission
occurred. The earlier signed archive is from a different source and cannot be
substituted for this source.

## Evidence

Raw report and balance/network/server/compile stdout are retained outside the
checkout at `../qualification-seeded-start-db231a8-2026-10-09/`.
Four-peer individual logs:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-5r7sla`.
The prior comparison report remains at
`/tmp/kras-rockets-equal-grid-6000000-report/report.json`.
