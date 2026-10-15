# Shared melee AI input qualification

Runtime/test source: `62087b2dff069088fb7c531077f7dee7f6037f31`.
Acquisition fixture update: `f3f489f66bf36bcc8681b4ddf93151e179238b5a`;
only `test_rival_acquisition_delay.gd` differs, so runtime bytes are unchanged.
Branch: `fix/kras-melee-tap-actions`. Parent documentation commit:
`afacd9c`, runtime-byte-identical to tested crate checkout `6dcc155`.
No main merge, production deployment, certificate changes or Apple submission.

## Defect and scope

`AIBrain.maybe_attack` published a held ATTACK decision, while the actual
`Fighter._handle_buttons` only starts melee on `just_pressed(ATTACK)`.
Consecutive eligible decisions therefore did not restart an attack after its
cooldown. The shared helper now uses the existing one-shot `tap` mechanism.
Range, visibility/reaction gates, random attack probability, RNG draw count,
fighter cooldown, stats and difficulty profiles are unchanged. Tank held-fire
and other explicit held-action callers are not converted indiscriminately.

## Direct regression

The stationary decision fixture uses an actual Duel Pit match context, actual
InputRouter edges and Fighter timer/button handling. Movement and collision are
isolated so the test measures the input contract, not match win rate. Fixture
reaction delay/noise/mistakes and attack probability are overridden only in the
fixture; shipped difficulty parameters are not modified.

Before runtime repair: 42 assertions passed, 8 failed (two failures per tier:
missing repeated press edges and missing repeated actual swings).
Local macOS evidence: `/tmp/kras-melee-red-local.log`. An earlier sandbox run
also failed, with an additional OS certificate-access error; it is not counted
as a clean runtime qualification.
After repair: 50 passed, then expanded to 70 passed, strict log guard passed.
Evidence: `/tmp/kras-melee-green.log`, `/tmp/kras-melee-expanded.log`.
The expansion preserves range, hidden-target, disabled-attack, probability-zero
and fresh target reaction-delay guards at all four difficulty tiers. Repeated
swings remain bounded by the actual Fighter cooldown.

## Natural sample

42 completed natural Duel Pit matches at seed offset 1200000: 24 baseline,
16 matched seed/character difficulty comparisons and 2 mutator smoke matches.
Independent report validation verified all eight matched pairs and 272 source
files with start/end fingerprint:
`d91c97e31bf6de281cd84d76a807277e79a4aa40a7fe3dc7285710174f35a680`.
Expert score share: 0.666666667; character bias: 0.0833333;
seat bias: 0.2083333; zero ties; no sampled report warnings.
Raw report: `docs/qa/melee-tap-2026-10-07/duel-pit-natural.json`.
Log: `/tmp/kras-melee-duel_pit-1200000.log`, strict guard passed.
This is one game's sample, not proof of all-game balance or a comparative
population-level improvement. Historical warnings in other games remain open.

## Retained failures and network evidence

First full gate failed: 390119 passed, four acquisition fixture assertions
failed because they inspected the old held `bits` rather than published input.
Evidence: `/tmp/kras-party-check.teJgaH`. This was not a successful full gate.
The fixture now checks actual InputRouter frames both before and at the reaction
deadline; its 109 assertions pass with a clean strict guard.
Evidence: `/tmp/kras-melee-acquisition.log`.

Two actual Godot clients, two Bots and a local WebSocket server completed the
scripted Duel Pit network fixture on 62087b2 (seed 309002). Host and guest
reconnected, agreed on `[7,5,35,12]`, and the guest received 1552 world snapshots.
Both stdout logs passed the separate strict guard. Server maximum loop delay:
32 ms; cumulative client maximum frame gaps: 936/929 ms. The fixture uses
35-second rounds and scripted human inputs, not production Internet or physical
players. Cumulative timing includes startup/transitions and does not establish
60 FPS, battery life or a stall's cause.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-WS99FL`.

## Base Siege comparison

Each side completed 42 natural matches at the same offset 1200000, with all
eight matched difficulty pairs and 272-file source identities independently
verified. Both strict log guards passed. Parent 6dcc155 used fingerprint
`0bb8ed8339b32f917284b874885bfdbaa8e0d90d82a7425b20c118fa73606c13`;
candidate f3f489f used the runtime fingerprint above.

| Source | Expert score share | Character bias | Seat bias | Warnings |
| --- | ---: | ---: | ---: | --- |
| Parent | 0.512048193 | 0.1666667 | 0.25 | Spawn advantage; Expert no better |
| Candidate | 0.537037037 | 0.1666667 | 0.25 | Spawn advantage |

The seat warning is present on both sources, not newly established by this
repair. The sampled Expert warning clears on this cohort; this is not proof of
universal balance. Base Siege remains balance-unqualified. Raw reports are
`docs/qa/melee-tap-2026-10-07/base-siege-before.json` and `base-siege-after.json`.

## Full corrected gate and remaining qualification

The corrected full gate on frozen f3f489f completed with exit 0 at
`/tmp/kras-party-check.rLVFx1`: 420 scripts compile, 519-resource inventory with
22 autoloads/27 routes/8 characters and zero issues. All 390123 assertions passed
(380.3 s), followed by the actual race, six boss checks and 39 stability matches
with zero failures. Every stage passed its strict runtime log guard. The
intentional memory-warning fixture drained caches; this is one cycle, not a
long soak, physical-phone measurement or proof of absent leaks. An earlier
parent exit ObjectDB leak failure remains unexplained, not claimed fixed.
Fresh server suite used all six captures from this exact run:
204 passed, zero failures/skips/cancellations/todo, 857.357084 ms;
`/tmp/kras-melee-server-tests.log`.

Physical phone/iPad QA, measured energy/thermal/FPS, production online deployment
and current-source native archive/upload/review submission are not complete.
Initial SSH pushes failed with GitHub Internal Server Error. Authenticated HTTPS
to the same repository succeeded without changing remotes, storing credentials
or force-pushing; remote f3f489f and crate documentation afacd9c were verified.
