# Zone Hold annular AI routing

Implementation: `f64817a4cb01d80d9c002ba2f61015dd3a6f1694`.
Parent: annular ground PR #28 (`814caa51e1902ac700577a81008ad76e95c5b1f1`).

## Reproduced defects

With corrected physical ground but the previous ZoneBrain:

- Opposite-zone steering still aimed directly through the central hole.
- Non-lethal falls bypassed the generic dash guard, allowing repeated falls.
- Retreat direction used absolute coordinates rather than the arena origin.

Regression before this fix: **1552 passed / 60 failed**.
Log: `/tmp/kras-zone-ai-baseline.log`.

## Changes

- Arena exposes annular path clearance and a short-chord waypoint toward the
  target. Routing uses public geometry, not private opponent state. Targets are
  clamped onto the band; an already-stranded bot first recovers radially.
- ZoneBrain preserves the existing difficulty steering error while following
  that waypoint. No movement speed, stats, attack odds or score bonus is added.
- The final publish hook checks the complete dash segment after input noise,
  including speed-item travel and the facing fallback. An unsafe dash is removed
  without discarding attack or other actions. Safe tangent dashes remain usable.
- Ring/oval retreat directions are origin-relative and use each band's centerline.

## Verified

Godot 4.7.1, isolated saves, existing warmed runtime:

- Zone Hold: **4664 assertions passed** (`/tmp/kras-zone-ai-complete.log`).
- AI visible targets: **135 assertions passed** (`/tmp/kras-zone-ai-visibility.log`).
- Compilation: **324 scripts passed** (`/tmp/kras-zone-ai-compile.log`).
- All three completed logs pass the repository log guard.
- 352 selected tracked Godot/data inputs matched the runtime byte-for-byte.
  This excludes asset/native/export provenance and is not an App Store archive.

Routing checks cover 12 initial angles, original and translated arenas, complete
kinematic movement to the opposite zone, both edges at every simulated step,
unsafe inward dashes, permitted tangent dashes, increased speed-item travel,
preserved attack input and 100 final noisy publish outputs. Existing scoring,
zone movement, physical-ground and guest-replica assertions remain included.
The visibility suite still passes; this does not certify every game's AI.
Kinematic route arrival is not evidence of a full natural physics match,
balanced win rates, or physical-device performance.

## Release gates still open

- Full current-source natural balance campaign, including the historical zone
  spawn advantage, and complete current-source integration/network matrix.
- Physical iPhone/iPad QA, controller/touch layouts, performance and thermals.
- Production online enablement only after network qualification; optional Apple
  identity flow and real app-to-production connection still need verification.
- Integration to main, a newly sourced signed archive, upload processing and
  review submission are separate operations, not achieved by this branch.

The macOS sandbox CA lookup diagnostic in the headless logs is not a production
TLS check. This fix introduces no save schema or network packet changes.
