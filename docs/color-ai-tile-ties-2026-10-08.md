# Color Stand: Seeded Equal-Distance Targets

Parent: `36b9339928fa0f7ded25b7ee73034398cbdea660`.
When two observable safe tiles were equally near, the planner always chose
the first tile in arena array order. A focused fixture reproduces this for
all four difficulty tiers: 41 assertions passed and four failed before the
fix (`/tmp/kras-color-tie-baseline.stdout`, exit one).

`safe_tile_near` now optionally accepts the AI's own seeded RNG and resolves
only final equal-distance candidates. Existing two-argument callers retain
their behavior. A unique closest tile does not consume RNG. The Color brain
passes its planner RNG, not the authoritative round RNG. Visibility,
standability, called-color checks, movement, reaction delays and rules remain
unchanged. No protocol or save schema change was introduced.

## Qualification

- Rendered tile-target suite: 181 assertions, exit zero, strict tests guard.
  Covers both tied candidates across seeds, identical choices when reseeded,
  unique nearest preference, unchanged RNG for unique targets, and the
  existing hidden-target tests for all tiers and all four tile game families.
  `/tmp/kras-color-tie-qualified.stdout`.
- Color network suite: 431 assertions, strict tests guard passes.
  `/tmp/kras-color-tie-network.stdout`.
- All 429 scripts compile, strict compile guard passes.
  `/tmp/kras-color-tie-compile.stdout`.
- Natural held-out sample, seed offset 3700000: 48 baseline, 24 mirrored
  same-seed/same-character difficulty matches and two smoke matches completed.
  Strict runtime guard passes, source fingerprint unchanged before/after:
  `046b30e3aeb825d150a38b133cdd71b2ffc4b271d64a21c7c1d07ed9d96ce326`.
  Expert placement-point share 0.712, slot bias 0.1041666667, character bias
  0.0208333333, slot wins `[14,17,6,11]`, no automatic flags.
  Report: `docs/qa/color-ai-tile-ties-2026-10-08.json`.

The initial command without an explicit writable log crashed during engine
startup opening user logs. Two incorrectly prefixed suite-filter attempts
selected no tests and exited one. None is accepted as test evidence. The
baseline and qualifying commands use `--suite=ai_tile_targets` and explicit
temporary logs; they executed the intended suite.

This fixes a reproduced tie-order bias, not proven causation of the earlier
24-round spawn warning. The new seeds are not a controlled before/after
campaign comparison. Retain the original campaign warning and broader
qualification limits. The preceding 392440-assertion full suite belongs to
the parent source, not this gameplay change. Physical-device, production,
signed local Xcode archive, upload and review gates remain open.
