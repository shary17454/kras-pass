# Oasis cardinal approach correction - 2026-10-15

Status: scoped correction verified; Stage 0 remains QA_PENDING / MERGE_PENDING.
This is not character balance, device performance, production or release approval.

## Reproduced defect and change

The authored north/south approaches to the center measured 28.52 units, while
east/west routes measured 92.318272. The direct east/west approaches also crossed
unpainted terrain reaching 0.757450 / 0.496005 versus the center floor at 0.020000.
Projectile-height physics rays were already clear; this was not a ray obstruction.

Added only two bidirectional graph links, (4, 9) and (15, 20), in
`src/arenas/woodland_valley_layout.gd`. Existing points, cover and 30 connections
are retained. The layout now has 32 undirected / 64 directed connections.
The production consumer is TankWorld; other maps were not redesigned.

The new real-scene regression checks each authored spawn, actual world routing,
21 sampled ground heights per approach and real collision rays. All four routes
now measure 28.52 and sampled floor height is 0.020000.

## Verification

- Initial fixture parse error was fixed before collecting the baseline.
- Baseline approach suite: 99 passed, 10 failed; corrected suite: 109 passed.
- Existing terrain suite: 3575 passed, 1 failed on the old connection count.
  Updating that exact topology contract to 64 directed connections gives 3576 passed.
- Compilation: 462 scripts; full suite: 425476 assertions, exit 0, 259.6 seconds.
- Strict runtime-log guards passed. No source edits overlapped qualifying runs.
- Gameplay fingerprint before and after campaigns:
  `d2371393a99fd6dca7c29aa5d8d0f6438806e1179055318d76ac7c4e917a0dd2`.

## Natural matches

Each campaign ran 112 baseline + 56 difficulty + 2 mutator/smoke instances.
Total: 340 natural-duration match instances, not 340 independent balance samples.

| Campaign | Seed offset | Seat wins | Slot bias | Expert point share |
| --- | --- | --- | --- | --- |
| Matched | 96000000 | 39 / 18 / 36 / 19 | 0.0982143 | 0.4135472 |
| Independent | 98000000 | 37 / 25 / 27 / 23 | 0.0803571 | 0.4089286 |

Neither campaign raised the slot warning; both still raised
`expert bots no better than easy`. This does not establish universal spawn
fairness or improved Expert AI. No tuning followed the matched results.
Seed channels did not overlap. Character/seat/pair exposure and version-2 save
envelope checks passed; there were no tied or all-zero baseline rows.

## Visual inspection and limitations

Four rendered desktop captures were inspected: Arabic with one human and English
with four human slots, each in portrait and landscape. The captures passed their
automated checks and show terrain, characters, HUD and touch regions. They do not
prove four real simultaneous human inputs, iPhone/iPad quality, FPS or thermals.
Compatibility rendering reports unsupported screen-space AA and BPTC fallback;
foliage appears stippled. These are remaining visual/device qualification items.

## Evidence

Sibling directory: `../qualification-oasis-route-parity-2026-10-15/` contains
baseline/fixed logs, compilation/full-suite logs, both JSON/HTML campaign reports,
and `visual-ar1/` / `visual-en4/` captures. No private save contents were copied.

SHA-256:

- Full-suite log: `6487a7937940638d00f3c80c5236456a8b59710e9b2cdfdb66b77b1e507037e0`
- Matched report JSON: `a2723535aef8cbc889978f6bfb722d9f3b7e6b908c7c81810dcce5d0d3afac72`
- Independent report JSON: `c76b94714e0617ac45c810a92a22ffda38ddb50361a1f63e7c9b1bfc7eb3f125`

No merge, push, Railway mutation, Archive, upload or Apple submission occurred.
Expert AI, remaining minigame balance, physical-device QA and production/release
gates remain open. Historical failed/candidate evidence is preserved separately.
