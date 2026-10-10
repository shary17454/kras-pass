# Duel Damage and Life Contract

## Held-out Result Before This Correction

Parent checkpoint: `d250c17aeac95ba525648eefde9f0972b9fee597`, branch
`feature/kras-online-random-rotation`, repository
`https://github.com/shary17454/kras-pass.git`.

The spawn-corrected gameplay fingerprint was
`72ad61069780e589372eb55c860c083d23cffc8b5f1d2910d0ec0801b50f45fa`.
A sequential held-out campaign used Godot 4.7.1 official, fixed simulation rate
60, and the unchanged authored-duration balance harness:

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-spawn-heldout-84000000.engine \
  tools/balance_sim.tscn -- --runs=96 --only=duel_pit --balanced-rosters \
  --seed-offset=84000000 --out-dir=/tmp/kras-duel-spawn-heldout-84000000-report \
  --test-data-dir=/tmp/kras-duel-spawn-heldout-84000000-save
```

All 96 natural matches, 48 mirrored difficulty comparisons, and both smoke
instances completed in 317.8 seconds, exit 0; both strict log guards passed.
Start/end source fingerprints matched. Baseline seeds and rosters exactly match
the historical pre-spawn-fix held-out campaign, with no overlap with the 80000000
baseline seed set. Every character appeared 48 times.

| Metric | Held-out spawn-corrected result |
| --- | ---: |
| Sakhra credited wins | 27 / 96 |
| Character bias | 0.15625 |
| Seat bias | 0.0208333333333333 |
| Expert point share | 0.656063618290258 |
| Mean natural duration | 60.5265624999979 s |
| Ties / zero-score matches | 0 / 0 |
| Flag | character advantage |

Seat wins were 25,23,22,26. Character wins were Barq11, Fanoos8, Ghaim2,
Mowja9, Nabta17, Ramla10, Sakhra27, Turs12. This contradicts any claim that the
initial flag-free 80000000 candidate sample settled character balance. The
spawn defect is fixed, but its held-out character warning remains retained.

## Proven Rule Defect

The Duel controller explicitly states that damage does not kill and instead
increases knockback. Its Arabic/English rules describe accumulated damage and
three knockouts. However, Fighter._apply_hit also subtracted shared base health
and emitted knocked_out at zero, causing the Duel controller to spend a life
and reset damage before a ring-out. This is a rule contradiction, not proof that
it explains Sakhra's advantage.

A new regression constructs real MatchScene fighters for all eight characters.
A hit exceeding base health must accumulate damage without spending a life;
the next push must increase; an explicit fall notification must still spend
one life and clear damage. A separate Ring Rumble scene must retain health-based
defeat. Movement is frozen, so the fall assertion tests the controller contract,
not an actual falling trajectory or physical-device presentation.

Before correction: 26 assertions passed, 32 failed, exit 1. There was no parse
failure. Damage reset to zero, lives fell from three to two, and the duellist
became inactive solely from health damage.

## Narrow Correction

- Fighter now has `health_defeat_enabled`, true by default. Damage accumulation
  and knockback always retain their existing path; health subtraction and
  health-based defeat require that policy.
- Only Duel Pit disables the policy when building its fighters. Other games
  retain their previous default behavior. No global stat, resistance, AI,
  geometry, save schema, acceptance threshold, or network packet change.
- `tests/suites/test_duel_damage_lives.gd` is registered in the standard runner.

New selected gameplay fingerprint:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
The imported runtime and checkout were compared; fixture/runner files were also
compared separately because the gameplay fingerprint does not include tests.

| Check | Result |
| --- | --- |
| Targeted regression | 58 assertions, 2.3 seconds, exit 0 |
| Fresh full suite | 408391 assertions, 438.6 seconds, exit 0 |
| Compile check | 452 scripts, exit 0 |
| Targeted/full/compile strict stdout and engine guards | Pass |
| Fresh four-client Duel network fixture, seed 80009001 | PASS, parent exit 0 |
| Network strict stdout/engine guards | Eight logs pass |

Network results were `[22,3,15,1]` on all peers, with unique IDs 1 through 4,
movement, matching round histories, and restored reconnecting IDs 1 and 2.
This fixture uses synthetic inputs, a shortened duration, and localhost only.
It is not natural-duration balance, real-human play, host migration, Railway
qualification, or device FPS/thermal/battery acceptance. Raw timing counters
remain in its logs.
The cumulative frame-gap maximum was 692 ms; server timing recorded no stall
and a loop maximum of 48 ms. These are not a steady-state device FPS result.
Intentional failure-injection ERROR lines and macOS startup
warnings remain in the full-suite evidence; passing guards is not zero logged
errors.

## Evidence and Next Gate

Raw held-out reports, failing/passing regression logs, full-suite and compile
logs, and fresh network evidence:
`../qualification-duel-damage-2026-10-10/` outside Git. Original failed evidence
is retained. No source changes occurred during any qualifying campaign.

The 72ad held-out result and previous 39-game/network reports are historical
after this rule correction. Re-run natural independent/held-out balance and
the wider current-source qualification before marking games READY. Neither
the correction nor successful regression establishes character balance.

Stage 0 remains QA_PENDING/MERGE_PENDING; later gated stages remain locked.
No main promotion/push, Railway deployment/migration, fresh signed Archive,
upload, or Apple review submission occurred. Production backup/restore and
physical-device acceptance gates remain open.
