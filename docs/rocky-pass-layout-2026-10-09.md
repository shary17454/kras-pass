# Rocky Pass Authored Layout

Base commit: `4dfa2fabcde019df858c599bde7bcc9993e2e86a` on the feature branch.
Runtime fingerprint before and after qualifying tests and natural simulation:
`7d43fd393812d503604d5cf81aa7f4f4a163e0714a9782ddbb4c92752eef39a1`.

## Implemented

`tank_foundry` / Rocky Pass now uses an original double-loop road network:
16 outer junctions at radius 36, eight inner junctions at radius 18 and one
central junction. Its 36 bidirectional edges include radial shortcuts. It is
no longer the same 5x5 street grid as the other two tank worlds.

RockyPassLayout supplies junctions, edges and sixteen cover positions. Terrain
height and the baked vertex road mask both use distances to the actual network
segments. Thus AI routes, driveable ground and road appearance share one
definition. The fragment shader uses a vertex mask, not a per-pixel loop over
road segments. NaturalValley exposes a white-by-default terrain colour hook;
other worlds retain their existing appearance logic. The road-distance query
caches its last sample, reused during colour/height mesh construction.

Ground between the routes rises into rocky ridges. Covers follow the actual
ground height and retain their original scanned meshes and verified cached
convex hulls. No character, weapon, damage, score, input, timer or save-schema
change was made. This changes gameplay geography and requires new balance and
network qualification; it is not merely a cosmetic change.

## Tests And Captures

- Initial red terrain test rejected the old grid and missing authored road mask.
- Focused initial green: 3148 assertions. Expanded connectivity/height tests
  subsequently passed within the complete regression.
- All 445 scripts compile; runtime log checker passes.
- Final full suite: 406683 assertions, 292.7 seconds, exit 0, strict tests log
  checker passes. It includes connected route steps, level samples along all
  36 edges, equal cardinal spawn approach heights, raised terrain between roads,
  original hull containment, one rendered/physical terrain surface, real
  traversal and shell collision with the actual raised cover.
- Real local Metal: two four-human Arabic captures, portrait 540x960 and
  landscape 1280x720, two additional live seconds, zero capture failures,
  exit 0; both manually inspected. Vehicles remain visible and the radar shows
  the new network. The strict runtime visual log passes.
- Natural simulation: eight baseline games with rotated seeded character
  partitions, sixteen mirrored Easy/Expert cases and two mutator smoke cases;
  all complete, exit 0. Seed offset 11200000, 150-second natural rule window,
  no clipped-round mode. Baseline draw rate 0, mean duration 68.21875 seconds,
  slot wins [2,2,1,3], Expert point share 0.5625, flags empty. Source fingerprints
  match at simulation start/end. This small sample is not a full balance review.
- `git diff --check` passes.

All raw evidence is retained at `../qualification-rocky-pass-layout-2026-10-09/`.
Intermediate failures are preserved: the first implementation had an angle
type-inference error; an expanded test counted edges inside its node loop and
sampled a road shoulder instead of an interior ridge. The first full suite
also exposed old grid-length and ground-level cover assumptions. Tests now
verify real edges and a centre-height ray hitting the rock itself; shell
stopping remains required. A second full run failed loading the updated fixture
because its dynamic ray result needed an explicit Dictionary type. The final
compile and full run above, not these earlier attempts, qualify the change.

## Previous Core Evidence And Open Scope

GitHub Core run 37974597119 completed successfully on
`e8b83fe74e39a6905882c27e545adb37f90b673e`, tree
`6e9d15201d62afac1274cec2567d1ebb6f0f1a63`, with intended head and checkout
matching and no tracked changes. Downloaded evidence confirms 406421 assertions;
all 23 retained log/stdout files pass the checker. Evidence is retained at
`../qualification-core-e8b83fe-2026-10-09/`. This predates the layout change.
Network run 37970339411 and balance run 37971414154 were still queued on d9841d2
when checked and were neither cancelled nor restarted.

Woodland Valley and Pine Highlands still need distinct authored geography.
Photorealistic content polish, all-map manual QA, broader paired balance,
physical-device performance/energy/controller tests and current-source network
acceptance remain open. Production backup/restore authorization, device
replacement authorization and release gates remain unchanged. Existing signed
archive/IPA does not contain this layout. No main push, production deployment,
migration, App Store upload or review submission occurred.
