# Recorded tank final regression - 2026-10-09

## Original failure

Game Quality run 37834212081 completed with one failed job, network-tank_arena (113507017038), from commit `47d33475d7e93a33eb82b4c4a3d48ad0e8c6626a`. The three ordinary tournament rounds completed. Final epoch 4, tank_oasis, seed 15775892 failed the existing shot/armor/inventory assertion: shots and ammo were observed, but no armor damage occurred before the safety watchdog.

Downloaded checkout evidence confirms that exact commit, empty tracked diff and scenario. The failed result is retained, not relabeled or cancelled. Completion of the other jobs is not a substitute for current-source network qualification.

Running a whole tournament with --seed=970791874 completed locally, but did NOT reproduce the final. That option returns the same seed for each round, unlike the original random sequence. It is not evidence that the original fault was absent.

## Reproduction and correction

`--tank-final-checkpoint` restores only the three recorded preceding score arrays:

```
[475,475,500,472]
[500,485,500,440]
[475,450,435,500]
```

The resulting points are [10,7,10,7], cups [1,0,2,1], contenders [0,2]. The real final then runs with the original seed through two Godot processes and a loopback WebSocket server. It does not teleport players, spawn artificial damage, edit armor/ammo, relax the hit assertion or change shipping gameplay.

This reproduced the same missing-damage failure locally. The test input driver always followed the road graph, including when direct pursuit was clear. It now discards a stale detour when three collision rays spanning vehicle width are clear. Obstacles still require graph navigation. This is a test-driver correction, not a change to the shipping AI, speed, projectiles, armor or win rules.

## Verified results

- Focused Godot tank tests: 170 assertions pass, including actual center/side obstacle collision checks and cached-route behavior.
- Recorded final after correction: PASS, host and guest scores [478,100,470,200], champion [0], points and cups unchanged. Both peers reconnected; guest observed 790 world snapshots. All original hit/inventory assertions remain enabled.
- Four-human tournament, seed 87173: PASS across tank_oasis, tank_frost and tank_foundry. All four independent engine processes agree on results and champion [3]; host and one guest reconnect successfully.
- Full headless regression: 392985 assertions pass in 178.5 seconds. Strict log guard passes.
- Full Node suite with loopback access: 248 pass, zero failures, six capture-dependent tests skipped because their optional world-fixture environment variables were not supplied. Do not call this zero-skips validation. The sandbox-only attempt was denied loopback listen (EPERM), then re-run with the required local access.
- Node checkpoint unit tests: three pass; invalid rooms and an unchanged no-hit tie are rejected/handled without inventing a winner.

The initial corridor implementation had GDScript type-inference errors; that failed attempt was stopped and explicit types were added before the successful runs. An inline inherited driver probe also failed class resolution and was replaced by tests using actual physics queries. No failed attempt is counted as successful evidence.

The recorded final is now part of the tank CI scenario, in addition to ordinary match and full tournament tests. That updated CI job has not yet completed; local success is not a replacement for a fresh all-game CI matrix.

## Source and remaining gates

Based on `4eeff2720f1e00176c395190b7c9762b07f66a44`; this patch changes test/support/workflow files only. Runtime fingerprint is unchanged: `1f990ad6a3691bc4b9bd1b9dd32aefca026c74a76ac9d2ad68de2bc25689e52b`.

The completed natural balance campaign 37848511748 was independently verified from all 39 raw game artifacts: 1638 completed matches, matching seeds/character difficulty pairs, source commit 3e83904 and fingerprint 4bcd0fb2fc4db5dd8df1c02b31065b182d12db0282d66ab61071eb9b7c982ed2. It retains warnings for blast_ball and scrap_karts (Expert bots no better than Easy) and sweeper_storm (character advantage). `balanceReviewComplete=false`, `releaseReady=false`. It does NOT qualify the later ice-batching source; no fingerprint was relabeled.

Physical iPhone performance/thermal/battery QA, production readiness, current-source balance warnings, source promotion and a fresh Xcode 27 archive remain separate release gates. No merge to main, Railway production change, Apple upload, processing or review submission occurred in this work.

## Evidence

Raw logs and verified old-source balance summary are retained outside Git in `../qualification-tank-final-2026-10-09/`. The original per-peer failed artifact is `/tmp/kras-tank-failed-37834212081`; the downloaded full balance campaign is `/tmp/kras-balance-37848511748-all`.
