# Keeper interception candidate (not release-qualified)

## Behavior corrected

The keeper used a constant 0.05-0.45 second forecast rather than the observed
trajectory's crossing time at the defensive line. Its close-ball approach also
aimed off a lane to which Goal Guard physically constrains human and AI keepers.
Normalizing this impossible movement reduced useful lateral input. Targets now
stay on the reachable lane and use delayed observed motion, bounded arrival
prediction and difficulty-dependent interpolation. No live/private ball velocity,
extra speed, score bonus or bypass of reaction delay was added.

## Source and tests

- Gameplay change: `0e992995df55b38b112dfdf1ff2afd5177d27d95`.
- Final regression fixture: `ff7edf6b20e8eee7cc6a6a6c6fc8ded8f81723ae`.
- Previous keeper source: `28c374eb83239138a78a3da303d8a0ad4ce61883`.
- Same final fixture on old source: 124 passed, 20 failed, exit 1.
- Final Goal Guard tests: 144 assertions passed, exit 0, including all four
  defensive directions, departure/parallel motion, lane bounds, close-ball lane
  constraint, lower prediction, actual shield saves and replica behavior.
- Shared perception regression: 119 assertions passed; hidden/queued balls,
  delayed observations and inferred rather than private velocity remain tested.
- Magnet Court network/authority tests: 190 assertions passed.
- Compile check: all 324 scripts pass; diff whitespace check passes.
- Runtime checkout: `/tmp/kras-cloud-export-uid-check`, with source/data/Godot
  test files byte-compared to the publishing checkout with zero mismatches.
- Independent old-source fixture: `/tmp/kras-keeper-baseline-check`.

Logs: `/tmp/kras-keeper-exact-baseline.log`, `/tmp/kras-keeper-exact-fixed.log`,
`/tmp/kras-keeper-visibility.log`, `/tmp/kras-keeper-magnet.log`,
`/tmp/kras-keeper-compile.log`.

## Full-round simulations and remaining issue

Each affected game ran 24 natural matches, 16 matched seed/character difficulty
samples with mirrored Expert slots, and two mutator/chaos checks: 84 completed
matches across both games. Reports are retained next to this document.

| Game | Prior Expert score share | Candidate share | Candidate flags |
|---|---:|---:|---|
| goal_guard | 0.514423076923077 | 0.533653846153846 | none |
| magnet_court | 0.524038461538462 | 0.509615384615385 | expert bots no better than easy |

Both had zero observed ties and passed both mutator checks. Prior evidence is
matched campaign 37113379841 at source c97cd88e88e9e957120d49027a33494828cb392e.
These are score shares, not win rates or statistically conclusive population
estimates. Local report logs: `/tmp/kras-keeper-balance.log` and
`/tmp/kras-keeper-magnet-balance.log`.

Magnet Court inherits the corrected keeper decision and still waits for a
multi-ball opportunity at higher strategy levels. Its new difficulty review
flag must be investigated with visible incoming-ball/ability-deadline fixtures
and repeated paired simulations. Do not silently waive this flag, add hidden
speed/accuracy bonuses, or claim the shared AI is now release-ready.

This candidate is held for review; no main merge, signed archive, Railway
activation or App Store submission is justified by these results. Full remote
regression, broader balance, physical-device QA and final release-source gates
remain independent requirements.
