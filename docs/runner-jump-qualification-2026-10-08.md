# Hurdle runner jump qualification - 2026-10-08

## Frozen source

Runtime/tests commit: `874d9e2de43168d747ff0f599ae0d3c4842f7bbf`.
Parent: `d46256f0a7f6690df7a270ac63e6b481a23df688`.
Branch: `fix/kras-runner-jump-actions`.
Natural fingerprint (274 files):
`d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e`.

Runner's direct visible-obstacle JUMP request now uses a one-consumption tap.
The physical raycast, difficulty jump threshold, dash draws, movement,
Fighter gravity/jump velocity/floor checks and balance thresholds are unchanged.
Climber, Dodger, shared maybe_jump and Draw are not changed here.

## Actual physics regression

New `test_ai_jump_actions.gd`, registered in the existing test runner, uses an
actual collision floor, tall persistent raycast wall, InputRouter and
Fighter.tick/move_and_slide. The fixture LaneRunner overrides lateral steering
only, not raycast, decision, publication, floor state or jump physics. It
isolates repeated recovery requests rather than an ordinary playable hurdle.
The isolated floor is outside the arena's ordinary geometry; controller/scoring
do not advance. Fixture mistake/noise/dash settings do not change gameplay.

Initial unconstrained-lateral RED `/tmp/kras-runner-jump-red.log` failed 12
assertions; the corrected lane-isolated RED
`/tmp/kras-runner-jump-red-lane.log` exits 1: 13 pass / 12 fail, 1.2 seconds.
Each tier publishes one edge while initially airborne, then lands once without
ever jumping, trapped at the physical wall. GREEN
`/tmp/kras-runner-jump-green.log` exits 0: 25 assertions, 1.2 seconds.
Each tier publishes 57 edges and executes seven actual jumps/seven landings over
361 ticks. Removing the wall releases the jump request; airborne requests cannot
continuously launch the fighter. Strict positive-summary guard passed.

The old close-contact runner test now checks the actual published frame, not
the held-only `brain.bits` field. Its first adaptation incorrectly read slot 0
for a slot 3 fixture, retained at `/tmp/kras-runner-recovery.log` (exit 1).
Corrected `/tmp/kras-runner-recovery-fixed.log`: exit 0, five assertions,
0.9 seconds. No test threshold was weakened or test dropped.

## Natural execution

Hurdle Dash seed offset 1200000: 42 completed matches (24 baseline, 16 paired
difficulty, two stress), eight verified difficulty pairs. Terminal exit zero,
matching start/end source fingerprint and strict runtime guard passed.
Expert score share 0.697531; character/slot bias both 0.166667; tie rate zero;
no review flags. Raw report: `docs/qa/runner-jump-2026-10-08/hurdle_dash-1200000.json`.
Log: `/tmp/kras-runner-jump-hurdle_dash-1200000.log`.
No fresh parent natural comparison, so no claim that a prior difficulty/seat
warning was cleared or that the parent-relative win rate improved.
Validator execution is complete but `balanceReviewComplete=false` and
`releaseReady=false`. This sample is not all-game qualification.

## Full gate

Full gate `/tmp/kras-party-check.7HLCbb`: terminal exit zero, 422 scripts
compile; 522 resources, 22 autoloads, 27 routes, eight characters, zero issues.
390507 assertions passed in 276.3 seconds. Actual race and all six boss
invocations passed. One stability cycle: 39 matches, zero failures. All stdout
runtime guards and the test positive-summary guard passed. Runtime/tests are
unchanged after the source freeze. Intentional negative fixtures, simulated
memory warning and native CA-access warnings remain in logs; not an error-free
log, long soak, physical-device performance or leak-free certification.

Server suite used all six fresh Godot captures from this gate: 204 passed,
zero failures/cancellations/skips/todo, terminal exit zero, 675.040291 ms.
Log `/tmp/kras-runner-jump-server-tests.log`. Localhost test permission only.

Read-only GitHub main inspection on 2026-10-08 still returned
`062a40992b92958573e28e19d8c8c1840560797a`; this development branch is not the
production release branch. Earlier campaign 37681747733 was live on 8907f94
with 34 completed jobs, four queued and two simulations running when checked;
it predates the direct race/crate/retreat/ball/boss/jump fixes and cannot qualify
this source. Do not cancel/restart it merely because its status is queued.

## Release scope

No main merge, production data operation/deployment, phone installation, native
archive, signing, Apple upload, processing or review submission performed.
All-game current-source balance/product review, unresolved warnings, real
iPhone/iPad graphics/FPS/thermal/energy/input measurements, production online
rollout and exact-source local Xcode 27 Distribution archive remain gates.
No Xcode Cloud, P12 import, new certificate or certificate revocation.
