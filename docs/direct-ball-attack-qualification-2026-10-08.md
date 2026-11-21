# Direct ball attack qualification - 2026-10-08

## Frozen source and scope

Runtime/tests commit: `d35f3e39e4408e15c3e8a2edf2c1fbc416789d82`.
Parent: `cdaad4d8b163d5dc8f0cd86e2ffa6345b17bcbd1`.
Branch: `fix/kras-direct-ball-attack-actions`.
Natural source fingerprint, 274 files:
`56eba83c3d8e38ed4fb77c2e041df217afd7bf4467703161a89824f782419f42`.

Keeper and Blast ball brains now publish their direct ATTACK decisions as
one-consumption taps, not held buttons. Fighter consumes an attack rising edge
and enforces its existing 0.55 second cooldown. Magnet and Storm inherit the
Keeper path. No probability, RNG draw, perception guard, fuse risk, physics,
character stat, cooldown or balance threshold was changed. Continuous tank
fire is untouched. Boss plan attack paths and Draw remain outside this repair.

## Actual input regression

`tests/suites/test_ai_tap_actions.gd` uses stationary Keeper/Blast subclasses
that override steering only. Actual brain ticks, InputRouter publication and
Fighter timers/buttons are used for 181 ticks at all four AI difficulties.
Repeated edges and cooldown-limited swings are checked; each executed swing
is applied to the actual Keeper reflection or Blast deflection response.
Stationary contact injection isolates the input contract; it is not natural
physics overlap evidence. Keeper charge is not refilled to bypass its limit.
Hidden ball, out-of-range, reaction delay and invisible Blast fuse guards are
also checked. Fixture-only probability and reaction parameters are not gameplay
changes.

RED: `/tmp/kras-direct-ball-attack-red.log`, terminal exit 1,
314 passing / 16 failing assertions, 19.9 seconds. Repeated-edge and repeated-
swing assertions failed; contact/cooldown assertions passed. GREEN with expanded
guards: `/tmp/kras-direct-ball-attack-green.log`, exit 0, 358 assertions,
23.0 seconds, strict log guard passed.

## Natural execution

Each game completed 42 matches: 24 baseline, 16 paired-difficulty and two
stress variants. Eight matched difficulty pairs per game were verified.
All four runs ended with exit zero and matching start/end source fingerprints;
168 completed matches in total. No fresh parent comparison was run, so these
samples do not quantify an improvement against the parent.

| Game | Seed offset | Expert score share | Character bias | Slot bias | Review flags |
| --- | --- | --- | --- | --- | --- |
| goal_guard | 1200000 | 0.533654 | 0.125000 | 0.041667 | none |
| blast_ball | 1200000 | 0.575000 | 0.083333 | 0.125000 | none |
| magnet_court | 1200000 | 0.528846 | 0.083333 | 0.250000 | spawn slot advantage |
| storm_heart | 1200000 | 0.524038 | 0.083333 | 0.083333 | none |

All four tie rates are zero and both stress variants passed for each game.
Magnet's warning is retained, not cleared or attributed to a cause from this
sample. Each validator reports complete execution but
`balanceReviewComplete=false` and `releaseReady=false`.
Raw reports: `docs/qa/direct-ball-attack-2026-10-08/`.
Original logs: `/tmp/kras-ball-tap-{game}-1200000.log`.

## Full gate and server tests

`/tmp/kras-party-check.A9pZHz`, terminal exit zero: 421 scripts compile;
521 resources, 22 autoloads, 27 routes, eight characters, zero inventory issues.
390411 assertions passed in 238.8 seconds. Actual race and six boss invocations
passed. One stability cycle completed 39 matches with zero failures.
All stdout stages pass the runtime guard; `tests.stdout` also passes the
positive test-summary guard. An additional post-run check incorrectly used
test-suite summary mode for a boss smoke log and failed on its absent suite
summary; correcting the invocation to the gate's runtime mode passed without
changing source or rerunning the matches.

Server tests used all six fresh Godot world captures under `saves-tests`:
204 passed, zero failures/cancellations/skips/todo, 789.5355 ms, terminal exit
zero. Log: `/tmp/kras-direct-ball-attack-server-tests.log`.
Localhost test permissions only; no production database operation.
Intentional negative fixtures, simulated memory warning and native CA-access
warnings remain in logs. These results are not an error-free-log, long soak,
phone FPS, heat or battery claim.

## Local network smoke

Four scripted Godot clients, `blast_ball`, seed 309011, terminal exit zero.
All clients agreed on scores `[16,8,4,17]`. Host and guest reconnect succeeded.
Guest world snapshots: 1107, 1088 and 1107. All four peer stdout logs pass the
strict runtime guard. Server loop maximum 53 ms; cumulative client frame gaps
647/634/645/631 ms include loading and reconnect and are not steady-state FPS.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-akmfST`.
Peer logs stay local because they may contain resume credentials.
This is not four physical users, public Internet or a tournament qualification.

## Apple session and remaining gates

Chrome login verified live and the TestFlight page refreshed on 2026-10-08:
Kras Pass app 6801506973 shows version 1.1.10 build 107, Ready to Submit.
No newer build was visible. Login is not proof of upload or review submission.
No stale archive is selected or uploaded, and Xcode Cloud is not used.

Remaining: current-source all-game balance/product audit, Magnet and prior Lab
seat warning diagnosis, remaining direct-action contracts, physical-device QA,
production Railway qualification and a fresh exact-source local Xcode 27
Distribution archive with identity/version/build verification. No main merge,
protected production backup, phone replacement, native archive, Apple upload,
processing or review submission is performed by this qualification.
