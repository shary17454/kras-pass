# Accepted Jump Observation

Parent: `1a327e0`, branch `feature/kras-online-random-rotation`.

The fighter emits `player_jumped` only after accepting a grounded jump.
The development contact probe counts accepted jumps separately from sampled
jump requests. This does not change physics, AI parameters, damage, scoring
or character balance. Acceptance is not proof of hazard avoidance or landing.
The probe ignores feedback before a round, after elimination and after finish,
and disconnects its listener during cleanup. No remote telemetry is added.

## Verification

- Initial unit RED: 17 passed, two failed for missing diagnostic contracts.
- Focused unit GREEN before two final guard assertions: 24 passed.
- Physical fixture: 67 assertions passed across eight characters, including
  accepted launches and rejected airborne requests.
- Final full regression: 405988 assertions passed in 212.0 seconds; exit zero
  and strict test log checker passed.
- Compilation: all 442 scripts compiled, exit zero.
- `git diff --check` passed.

Observed and control natural simulations each completed 64 baseline matches,
32 paired-difficulty matches and two stress rounds: 196 matches total.
Seed offset was 6800000. Independent comparison of the entire reports after
removing only their generated timestamps passed. All observed rounds completed
with zero invalid contacts; accepted counts and exposure durations validated.
This establishes non-interference for this sample, not universal determinism.

Baseline character wins: barq 1, fanoos 8, ghaim 5, mowja 10, nabta 2,
ramla 3, sakhra 22, turs 13. Slot wins: [14,23,16,11]. Expert placement-point
share: 0.56875. The character-advantage warning remains open. Counts depend
on exposure duration; do not infer a causal resistance or jumping defect,
remove old warnings, or mark this minigame READY from this experiment.

Start/end source fingerprint for both runs:
`58c406442e225257c8d588bf96c6866f1c28f96f7b4ab3d9c77c230c4a01c91d`.

## Actual Water Camera Check

The visual QA fixture now records read-only water visibility and history size.
Rising Tide passed at 1280x720 landscape and 540x960 portrait, Arabic,
one human plus three Bots, after ten seconds of play. All three Bots observed
water with 32 history entries in both orientations. Both PNGs were inspected.
Water was below the floor at approximately -0.96/-0.98 m. This is not full
map, endgame, all-language or iPhone camera qualification.

## Raw Evidence

- `/tmp/kras-accepted-jump-full.stdout`
- `/tmp/kras-accepted-jump-unit.stdout`
- `/tmp/kras-accepted-jump-physical.stdout`
- `/tmp/kras-sweeper-accepted-observed-report/`
- `/tmp/kras-sweeper-accepted-control-report/`
- `/tmp/kras-sweeper-accepted-observed-save/contact-probe.jsonl`
- `/tmp/kras-tide-camera-1a327e0-visual/visual-report.json`

Main integration, production deployment, device QA, signing, upload and
App Review are separate acceptance gates and are not claimed here.
