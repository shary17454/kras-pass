# Direct race dash action qualification

Parent: `8907f94fd4e0eb18182b90df9fb6a460a155d1fd`.
Frozen runtime/tests: `80de705b8ea3b6f0448cb239dd6f181c06aa408e`.
Branch: `fix/kras-direct-race-dash-actions`.

## Repair and focused proof

The shared helper repair does not cover `racer_brain` and `runner_brain`:
both publish DASH directly. Racer Armed inherits the direct Racer decision.
Both direct requests are now taps because Fighter consumes DASH using
`just_pressed`. Only those two final requests changed. No speed threshold,
probability, RNG draw, racing line, jump action, perception, cooldown, charge,
character stat, physics or balance acceptance threshold changed.

Stationary fixtures run actual brain decisions and publication, InputRouter,
Fighter timer advancement and button handling for 181 ticks at each of four
tiers. Racer movement is stationary and Runner obstacle sensing disabled only
in these fixtures; accepted dash decisions are forced only in the fixture.
This isolates repeated edges and cooldown, not natural skill or perception.
Initial Kart/Runner RED: 186 passed, 16 failed in 16.2 seconds,
`/tmp/kras-direct-race-dash-red.log`.
Expanded Kart/Runner/Armed RED: 190 passed, 24 failed in 40.9 seconds,
`/tmp/kras-direct-race-dash-expanded-red.log`.
GREEN: 214 passed in 33.6 seconds, strict guard passed,
`/tmp/kras-direct-race-dash-green.log`.
Each path must publish at least ten input edges and execute three to four
actual boosts within the window, without bypassing actual cooldown.

## Natural balance

Each report has 24 baseline, 16 paired difficulty and two stress matches.
All three games completed (126 matches), with eight verified difficulty pairs each, stable
start/end source fingerprint (274 files):
`9c1818bac02eaad006dab6728529db8a84e36dc880b4c31556855e04bdac4ed1`.
All exited zero and passed strict log guards. Raw reports are retained in
`docs/qa/direct-race-dash-2026-10-07/`.

| Game | Offset | Expert share | Character bias | Seat bias | Tie rate | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| kart_sprint | 1200000 | 0.700000 | 0.115000 | 0.070000 | 0.041667 | none |
| hurdle_dash | 1200000 | 0.672840 | 0.166667 | 0.166667 | 0.000000 | none |
| sabaq_sawarikh | 1200000 | 0.700000 | 0.083333 | 0.083333 | 0.000000 | none |

One Kart baseline tie is retained, not discarded. No fresh parent comparison
is claimed, and unflagged selected samples are not all39 release acceptance.
Validation `complete=true` covers execution of the selected game; reports
retain `balanceReviewComplete=false` and `releaseReady=false`.
Armed qualification completed normally in 483.3 seconds; the quiet paired
phase was not classified as a hang or restarted. Its average match duration
was 130.7 seconds, not a physical-device frame-rate measurement.

## Local network check

`/tmp/kras-direct-race-dash-network.log`, two scripted human clients plus two
actual Bots, Kart Sprint seed 309008. Exit zero, both clients agree on
`[4942,4193,1999995924,1999996218]`; host and guest resumed.
Humans finished; Bots were unfinished and ranked by progress. This is not proof
that all four finished. Guest received 1482 world snapshots. Both peer logs
passed strict guards. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-eqsYoE`.
Server maximum event-loop delay 150 ms; cumulative client maximum frame gaps
1424/1349 ms include startup/loading/reconnect, not steady frame-time proof.
Full peer logs stay local because they may contain resume credentials.
No physical device, public Internet, complete tournament or battery/thermal
acceptance is inferred from this scripted local check.

## Full regression and server gate

`/tmp/kras-direct-race-dash-full-gate.log`, evidence
`/tmp/kras-party-check.mhywM8`, completed exit zero. All 421 scripts compile;
inventory: 521 resources, 22 autoloads, 27 routes, eight characters, zero issues.
Tests: 390267 assertions passed in 401.9 seconds. Actual race regression and
all six boss invocations passed. One stability cycle: 39 matches, zero
failures. All stages passed strict log guards. Intentional negative-save,
router, replay-budget and simulated memory-warning diagnostics, plus native
certificate-store access warnings, remain in logs. This is not an error-free
log claim, a soak test or physical-device performance evidence.

Server tests used all six fresh world captures from this exact gate's isolated
`saves-tests`: 204 passed, zero failed/cancelled/skipped/todo, 1136.924209 ms;
`/tmp/kras-direct-race-dash-server-tests.log`. Localhost permission was used for
test execution only; protected production data was untouched.

## Remaining release scope

Selected natural qualification is complete, but current-source all39 balance,
physical-device QA and production/native release gates remain outstanding.
Campaign 37681747733 is on parent 8907f94, not this source; do not
attribute its result to these additional race repairs. It was confirmed live
with one completed catalogue job and an active simulation during this turn.
No campaign was cancelled/restarted, no main merge, protected production data
operation, Railway deploy, phone installation, native archive, Apple upload or
review submission occurred. Full product scope remains unproven.

The direct ATTACK audit identified Keeper, Ball and Smasher requests whose
consumers use Fighter attack windows. They require separate actual-input and
cooldown regression before any change; Tank continuous firing and other held
semantics must not be changed merely by text replacement. No new direct
ATTACK or JUMP repair is included here.
