# Direction-independent vehicle acceleration and braking

Base source: 3aec344bbdce505f3435aeef1dbb772877ebeb3d.
Candidate simulation fingerprint before, after and independently recomputed:
`c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`.

## Confirmed defect and scoped fix

DRIVE applied acceleration and friction independently to velocity.x and
velocity.z. A diagonal change could therefore spend sqrt(2) times the declared
planar acceleration/braking budget. Road yaw affected the physical response,
despite identical character parameters and throttle.

The shared vehicle integrator now uses Godot Vector2.move_toward for one
horizontal budget. Vertical gravity, maximum speed, steering, character stats,
perks, tuning data, attack impulses and other locomotion types are unchanged.
Straight-axis acceleration and braking retain their original budgets. Diagonal
and lateral momentum changes intentionally no longer receive the extra budget.

This changes DRIVE trajectories, not only tests. Old-source balance/network
results or signed archives cannot be substituted for current-source acceptance.

## Tests

- RED: 545 assertions passed and 168 failed, including diagonal acceleration,
  diagonal braking and redirecting sideways momentum. This is a gameplay
  contract failure, not a parser error.
- GREEN: 713 passed; strict log check passed. The new 600 assertions span all
  eight characters, 30/60/120Hz integration steps, four headings, forward and
  reverse acceleration, braking, target-speed clamping and sideways momentum.
- Compile: all 442 scripts compiled; strict log check passed.
- Full regression: 405909 assertions passed in 238.6s; strict log check passed.
  This is not actual-device FPS, thermal, battery or human control acceptance.
- Four actual Godot peers plus local WebSocket service completed the armed
  race at seed 6009614. Starts and scores [18152,18822,18412,18645] matched;
  host and guest reconnected. Exit 0.
- Four actual peers completed the recorded three-contender tank final at
  tank_foundry: scores [300,100,410,200], champion slot 2, unchanged tournament
  points/cups, host and guest reconnect, shots/pickups/armor damage observed.
  Exit 0. Neither network fixture injected damage or bypassed evidence checks.

## Matched diagnostic balance cohort

64 natural baseline races, 32 paired difficulty races and two stress races
completed. Seed offset 6400000, seeded_partition_seat_rotation. Baseline seeds
and rosters match the previous unmodified-source cohort exactly. Every character
appears eight times in each seat. Source remained unchanged throughout.
No thresholds, roster policy or warning logic were changed.

| Character | Before | Vector budget |
| --- | --- | --- |
| barq | 18 | 15 |
| fanoos | 8 | 6 |
| ghaim | 12 | 10 |
| mowja | 4 | 7 |
| nabta | 10 | 8 |
| ramla | 8 | 10 |
| sakhra | 2 | 4 |
| turs | 2 | 4 |

Slots: [17,12,17,18] -> [17,18,16,13]. Original character-advantage warning
is absent in this cohort. Tie rate 0, average simulated duration 127.21s,
Expert edge 0.70; both stress passes succeeded. This supports the physical
correction, but is only one diagnostic cohort for one game. Larger independent,
legacy-roster and all-game campaigns remain necessary before READY/release.

## Evidence and outstanding scope

Raw logs/reports: `../qualification-drive-vector-2026-10-09/`.
Current-source all-game network and balance qualification remain open.
The full product requirements, physical iPhone/iPad QA, production backup/restore
authorization, Railway synchronization and exact-source local Xcode archive,
upload and App Review are not complete. No main merge or production action
occurred as part of this correction.
