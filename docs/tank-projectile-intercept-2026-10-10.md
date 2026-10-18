# Tank Projectile Interception

## Change

The tank brain used a fixed 0.2-second prediction horizon for every distance
and shell speed. It now solves the ground-plane intercept from delayed rival
position/velocity, weighted by the existing prediction skill, including reaction
age and the actual 1.6-unit muzzle offset. Forecast flight is bounded at two
seconds; degenerate/unreachable trajectories use a finite distance fallback.

The controller exposes only the bot's own loaded projectile speed. The same
shell-kind selection is used by actual firing, including empty ammunition and
ricochet-only rules. No live rival transform/velocity, hidden item information,
extra movement speed, damage, accuracy, or reaction bonus was introduced.

## Regression Evidence

Initial restricted Godot launch aborted with a native backtrace; retained as
an environment failure, not a test result. Local system-permission rerun before
the fix completed with 309 passing and 84 failing assertions, demonstrating
incorrect interception across all four tiers, three distances and seven shells.
The prediction=1 fixture isolates ballistics, not difficulty balance.

After the fix: 393 assertions passed. Expanded edge cases initially retained
one overly strict floating-point bound (413 passed, 1 failed). A 0.00001-unit
tolerance and ricochet-only case yielded 415 passed. Network regression: 192
passed. Complete regression: 407827 passed in 211.1 seconds. Compile: 450 scripts.
Server: 276 passed, zero skipped/failed, against six actual Godot world captures
from the complete regression. Strict completed-test/runtime guards passed.

Tests additionally cover stationary targets, ignored vertical velocity,
unreachable/equal-speed trajectories, disabled prediction, empty ammunition,
and unchanged delayed-cue behavior despite a different live rival velocity.

## Natural Balance Samples

Runtime source fingerprint before/after each simulation and in the current
checkout: `81d4dd3e0a19fe021cb38bff175bcf98c0a57d0cdd8940c264137de09032ba02`.
No source was edited during a qualifying local process.

Both samples use tank_foundry, natural rounds, balanced seeded partitions and
seat rotation, 96 baseline games + 48 paired-difficulty games + 2 stress games.
The paired games deliberately reuse seeds with swapped Expert/Easy seats.
The two samples have 122 unique seeds each including stress, and zero overlap.

| Seed Offset | Expert Share | Slot Bias | Character Bias | Average Duration | Flags |
| --- | --- | --- | --- | --- | --- |
| 16000000 | 0.5208333 | 0.0520833 | 0.03125 | 16.053 s | none |
| 24000000 | 0.5520833 | 0.0625 | 0.0520833 | 21.283 s | none |

All 292 match instances completed. Strict runtime guards and source-stability
checks passed; both mutator/chaos stress cases passed in each sample.
The first Expert share is close to the warning threshold. These samples are
supporting evidence, not proof of universal balance or iPhone performance.
The earlier independent warning at 0.51875 remains in its historical report;
it is not erased or combined into current-fingerprint evidence.

## Other Qualification And Open Gates

Core GitHub run 38020374703 completed successfully on ba3f9f8, with its source
manifest matching intended/checkout commit and clean tracked inputs. Its
407633 assertions, 117 stability matches/zero failures and 276 server-capture
checks passed strict guards, but precede this interception change.

Balance run 38018326003 completed on older 15279bf: all 39 reports, 1638 matches,
consistent fingerprint 96635c407c937275b23dec9a46e818342acb13b8f4a396c55e46cf65c70dd5eb.
All 39 simulation logs passed runtime guards. The campaign retains a character
advantage flag for sabaq_sawarikh (character bias 0.25). It does not qualify the
current source or remove expanded historical warnings. releaseReady=false.

No main merge, production mutation or Apple upload/review submission. The
76fe5ca signed archive is now an older-source qualification archive; rebuild
from a newly frozen release commit before an actual upload. Current all-game
balance, other tank arenas/variants, device/controller/thermal/battery tests,
production backup/restore/migration/connectivity and unfinished product scope
remain open. No stage is marked DONE and no game is promoted to READY here.

Evidence: `../qualification-tank-intercept-2026-10-10/`; external campaign
artifacts: `/tmp/kras-balance-152-38018326003/` and
`/tmp/kras-core-ba3-38020374703/`.
