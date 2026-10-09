# Woodland Valley geometry qualification

## Implemented

`woodland_valley_layout.gd` defines two mirrored winding meadow loops with
three middle crossings: 25 junctions and 30 bidirectional connections. This
replaces the old bent square grid only for `tank_oasis`. Rocky Pass retains
its separate concentric recipe; Pine Highlands remains unchanged.

The authored graph drives both the baked road mask and terrain height. All
four cardinal starts and sampled route segments retain level driveable ground.
Sixteen rock-cover placements follow the meadow recipe and rendered terrain.
Existing collision hulls, terrain observation mesh, controls, scoring, timers,
character tuning, and save format are retained. No imported art was added.

## Current source and local results

Parent commit: `2f2954e794fe37d2614009c88d66c29d1d25798d`.
Runtime fingerprint, unchanged across full tests and natural simulation:
`3a0bb279e96b392f1096dc9807dcb56e132031e558cad6318b7a39dece4c8e9b`.

- Focused terrain suite: 3566 assertions, exit 0.
- Full suite using the repository's `--fixed-fps 60` setting: 406908 assertions,
  499.6 seconds, exit 0. Strict test-log check passed.
- Compile check: 446 scripts, exit 0; strict log check passed.
- Local Metal visual harness: Arabic, four humans, portrait and landscape,
  2 captures, 0 failures, exit 0. Both images inspected manually.
- Overview harness: all three tank maps rendered, exit 0; strict log check
  passed. Woodland overview inspected manually.
- Natural `tank_oasis` sample: 8 baseline, 16 mirrored difficulty comparisons,
  and 2 mutator matches recorded complete; no flags in this limited sample.
  Seed offset 11500000, balanced rosters, matching start/end fingerprint.
  Strict log check passed. The process handle expired before its final exit
  status could be read; this report does not claim an observed exit code.

The initial full-suite invocation omitted the fixed-fps setting used by
`tools/check_party.sh`. It was explicitly interrupted (exit 130), retained as
incomplete, and not used as passing evidence. No round duration was shortened.

Evidence is retained outside the checkout at
`../qualification-woodland-layout-2026-10-09/`, including interrupted and
completed logs, natural JSON/HTML reports, and rendered screenshots.

## Separately audited earlier-source evidence

These results do not certify this new terrain:

- Core run 37979443855 and tank-network run 37979457755 succeeded at
  `7c2c77b2982c3f3fb86dc25458a152292f0ed47b`. Checkout attestations match that
  commit with no tracked changes. All 23 retained core logs and all 50 tank
  logs passed strict checks; core recorded 406683 assertions.
- Balance run 37971414154 completed at
  `d9841d2543f216bb1d989fd1dd7525e903c36d95`, fingerprint
  `54adea3029e2a4a5828d7b39023c874d1eb14eb21967e2acc9bc538404dc4f5d`.
  The paired campaign audit verifies 1638 natural default-arena matches,
  no missing games, and 117 clean retained logs. It still reports reviews for
  `rising_tide` (46% ties), `sky_court` (spawn advantage and difficulty),
  `sweeper_storm` (difficulty), and `tag_hunt` (spawn advantage).
  `releaseReady` remains false. These warnings are not resolved by this change.

## Remaining work

Woodland vegetation and grass remain too sparse/weak in the inspected image;
this is geometry progress, not photorealistic visual acceptance. Interior river
crossings, bridges, tunnels, additional distinct worlds, larger balance samples,
and human/device QA remain open. No physical-device FPS, heat, battery, or
controller test is claimed. No production migration/deploy, signed current
archive, Apple upload, or review submission occurred in this phase.
