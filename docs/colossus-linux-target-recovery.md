# Colossus reachable target recovery (2026-10-03)

Starting source: `25cb0bed76e07f5490b487b25daaabda11d83aa0`.

## Reproduced failure and cause

The main-source Linux x86_64 CI job `111031120008` in run `37065034908`
failed its real Colossus seed 345 match: final health 30, scores
`[165,165,220,220]`, no boss defeat. The suite before it passed, so this was
a gameplay completion failure rather than a compile failure.

The local Docker image `kras-relay-linux-check:local` (`1c6661f8a10f`),
containing Godot 4.7.1 Linux ARM64, reproduced exactly that final health and
score array. Source was mounted read-only, networking disabled and saves/logs
isolated under `/tmp/kras-colossus-linux-25cb0be`.

The added optional `--trace` harness flag records visible fist exposures,
fighter poses, candidate attack plans and clear-path checks. It does not
change inputs, tuning, duration or random draws. The trace showed fist
openings at positions such as `(-144.1569,1,-68.68113)` and
`(149.0248,1,-37.15984)`: the boss selected slots that were match-alive but
already falling far outside the arena or waiting to respawn. Such openings
had no reachable attack plan and consumed the same combat window.

## Fix and regressions

`_pick_target` still chooses uniformly from eligible players. Eligibility
now requires match-alive, a valid fighter, fighter-alive, visible, and actual
arena ground with the existing 0.5-unit clearance. If nobody qualifies, it
returns the existing no-target sentinel instead of slamming a respawn pose
or a distant falling player. It does not favor the damage leader or any slot.

The authored health, damage, exposure time, attack reach, slam timing and
round duration are unchanged. This fixes target eligibility, not navigation
around every possible crater layout, and does not claim input determinism.

The focused test puts one eligible player on ground, a hidden player on
ground, an inactive player on ground and a player over a crater. It samples
32 targets and then removes the last eligible player. Before the fix:
65 passed, 24 failed. After the fix: 89 assertions passed.
Logs: `/tmp/kras-colossus-target-before.stdout` and
`/tmp/kras-colossus-target-after.stdout`.

Linux ARM64 real matches after the fix:

| Seed | Defeated | Final scores |
| --- | --- | --- |
| 345 | yes | `[275,275,165,110]` |
| 9614 | yes | `[275,220,110,220]` |
| 172 | yes | `[220,220,220,165]` |

Evidence: `colossus-345.stdout`, `colossus-345-trace.stdout` (before),
`colossus-345-after.stdout`, `colossus-9614-after.stdout` and
`colossus-172-after.stdout` under `/tmp/kras-colossus-linux-25cb0be`.
No script/parse error or resource-leak diagnostics were found in the three
passing logs. This native ARM64 container is not the x86_64 CI environment.

## Complete local gate

`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.bDHQn3`:
310 scripts compiled; 348 resources audited with zero inventory issues;
20,628 unit/integration assertions passed; four racers finished three laps;
all three Colossus seeds and all three other boss regressions defeated their
bosses; 39 stability matches had zero failures. macOS seed 345 scores differ
from Linux despite both now defeating the boss. This is not a determinism or
general balance certification. Expected sandbox CA lookup and deliberate
failed-write diagnostics remain documented in the earlier qualification.

Server suite: 109 passed, zero skipped, using all four fresh Godot world
captures from this gate. Log: `/tmp/kras-colossus-target-server-final.log`.

The previous feature CI run `37053065343` was verified completed, with only
its old Hurdle networking scenario failing, before requesting a new feature
run. The new fix still requires Linux x86_64 CI qualification. It is not
merged into main automatically, and no Railway deployment, iOS archive,
upload or review submission is asserted here.
