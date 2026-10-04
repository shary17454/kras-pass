# Physics-clock crate input qualification

## Scope

Branch `test/kras-crate-simulation-input`, based on race recovery PR #50.
Only the network smoke player's attack cadence changes: it uses accumulated
physics delta during PLAYING/SUDDEN_DEATH instead of wall-clock modulo, and
resets outside those phases. The cadence remains a 200 ms press every 800 ms.
Runtime weapons, randomness, scores, damage and authority are unchanged.
The weapon and active-projectile observation gate is unchanged.

Wall-clock pulses could be skipped when the shared machine stalls between
physics ticks. This change removes that source of input scheduling variability;
it does not make Godot physics or the network fully deterministic.

## Evidence

Before: crate commit 1e3f497 plus diagnostic driver, fixed seed 1366831714,
four scripted human peers, three-match tournament FAILED with weapon=true and
shot=false on host and all guests. Evidence `kras-network-smoke-q0Idmw` under
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T`.

After: race commit a07df09 plus this physics-clock driver change:
`node server/network-smoke.js --game=lab_crates --tournament --humans=4 --seed=1366831714`
PASSED. Evidence `kras-network-smoke-wDcsmv` under the same temporary root.
All peers observed the weapon and an active projectile, completed three matches
and accepted matching final scores `[22,7,10,4]`, points `[11,8,10,5]`, cups
`[2,0,1,0]` and champion slot 0. Host and one guest reconnected. Other guests
stayed connected. Guest world snapshot counts were 1662, 1684 and 1684.

The reproduction supplies the same seed for each match, unlike the original
CI tournament's three different seeds. One local before/after result does not
establish universal causality or seed coverage. Server loop maximum 4270 ms
and host frame gap 4425 ms exclude smoothness qualification for this run.

Compile: 335 scripts passed, log guard passed
(`/tmp/kras-crate-simulation-compile.log`). `git diff --check` passed for the
driver change. Existing crate and race unit evidence is documented separately;
those suites were not rerun as part of this driver-only experiment.

## CI and remaining gates

Retain the successful fixed-seed four-peer tournament in addition to the
existing ordinary and randomized tournament groups. No assertions, process
deadline or job deadline are relaxed. The added group has the existing 360 s
process bound; the lab scenario's total group bounds become 24 minutes before
setup, within its existing 30-minute job budget.

Linux execution is still required. This is not main integration, Railway
deployment, physical-device testing, a Distribution Archive or Apple submission.
All original product and release requirements remain open until separately
verified; these two network regressions are only part of that qualification.
