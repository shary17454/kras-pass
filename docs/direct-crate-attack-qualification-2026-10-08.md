# Direct crate attack qualification

Parent: `4d0538b6ee96644342f0a571c1ccf6f2529a4b32`.
Frozen runtime/tests: `2cca6cc32f15cbf80820b9626bfbdf5c5cf5e8cd`.
Branch: `fix/kras-direct-crate-attack-actions`.

## Repair

Smasher's direct ATTACK request now uses `tap`, not `press`. Fighter consumes
ATTACK using `just_pressed`; an uninterrupted held request creates only one
attack edge even after cooldown. Crate Smash and its Lab Crates derivative
use this brain. No movement, RNG draws, classification accuracy, perception,
character stats, scoring, cooldown or balance thresholds changed.
Tank's held firing is intentional (`tank_arena.wants_fire`) and unchanged.
Keeper/Ball attack requests and held jump semantics remain separate audit work.
Read-only audit also found Generic's retreat scheduling checks changes to
held `bits` around `maybe_dash`, whereas shared dash now uses pending tap bits.
This consumer requires a separate actual-decision regression and repair;
it is not changed or claimed qualified by this crate patch.

## Actual-input regression

Stationary Smasher retains its real decision and visible-crate classification.
Fixtures force accurate colour classification and zero reaction/noise only to
isolate accepted attacks. Each of four tiers runs 181 ticks through actual
brain publication, InputRouter, Fighter timers/buttons and crate swing scoring.
One fresh safe rendered crate appears only after the previous swing ends.
The fixture requires repeated input edges, three to six actual swings and
one credited safe crate per swing. This is not a natural balance simulation.

Initial fixture used Node3D instead of the controller's required collision
body and caused teardown errors: `/tmp/kras-direct-crate-attack-red.log`.
That run is not a clean regression baseline. The fixture was corrected to
StaticBody3D before changing production code.
Corrected RED: 222 passed, eight failed in 20.1 seconds, all failures are the
repeated-edge/repeated-swing assertions across four tiers;
`/tmp/kras-direct-crate-attack-corrected-red.log`.
GREEN: 230 assertions passed in 17.2 seconds; strict log guard passed;
`/tmp/kras-direct-crate-attack-green.log`.

## Natural qualification

Three samples completed: 126 matches, eight verified paired difficulty
comparisons per sample, zero ties, both stress variants passed for every sample,
exits and strict guards zero. Lab received an independent held-out seed offset.
Start/end source fingerprint matched the frozen runtime: 274 files,
`32d49680806cbb54e56a21aee95a7f2ce28ef6661ab4f0faa1a9ff5d75e4719b`.
Raw reports: `docs/qa/direct-crate-attack-2026-10-08/`.

| Game | Offset | Expert share | Character bias | Seat bias | Flags |
| --- | --- | --- | --- | --- | --- |
| crate_smash | 1200000 | 0.691358 | 0.041667 | 0.083333 | none |
| lab_crates | 1200000 | 0.700000 | 0.083333 | 0.250000 | spawn slot advantage |
| lab_crates | 1500000 | 0.666667 | 0.083333 | 0.250000 | spawn slot advantage |

The Lab seat warning is retained and needs diagnosis, not a changed threshold
or hidden sample. No fresh parent natural comparison or causal balance claim
is made. Both independent Lab samples retain the warning. Execution is
complete; `balanceReviewComplete=false` and `releaseReady=false` remain true
in all three validators.

## Network qualification

Four scripted human Godot processes completed Crate Smash seed 309009, exit
zero, all four strict guards passed. All agree on `[19,13,9,13]`. Host and one
guest resumed; guests received 1107/1088/1107 world snapshots.
Server maximum event-loop delay 131 ms. Cumulative client frame gaps
917/904/875/1003 ms include loading and reconnect; they are not steady gameplay
frame-time or phone energy/thermal measurements. One local match is not
public Internet, four physical humans or a complete tournament qualification.
Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-S63EDU`.
Peer logs remain local because they may contain resume credentials.

## Full regression and server gate

Full gate: `/tmp/kras-party-check.aLsRHV`, terminal exit zero. All 421 scripts
compile; 521 resources, 22 autoloads, 27 routes, eight characters, zero
inventory issues. 390283 assertions passed in 379.9 seconds. Actual race and
six boss invocations passed; one stability cycle: 39 matches, zero failures.
All stages passed strict guards. Intentional negative harness/save/router/
replay and simulated memory-warning diagnostics plus native CA-access warnings
remain; this is not an error-free log, long soak or device-performance claim.

Server tests used all six fresh actual-engine world captures from this exact
gate's `saves-tests` directory. Terminal execution session 69962: 204 passed,
zero failures/cancellations/skips/todo, 956.84875 ms. Localhost test permission
was used; protected production data and configuration were untouched.

## Release limits

No main merge, production deployment or protected data operation, phone
installation, native archive, Apple upload or review submission is included.
Parent campaign 37681747733 uses 8907f94 and cannot qualify this new source.
All-game balance and product scope, physical-device performance and native /
production release qualification remain required before review submission.
