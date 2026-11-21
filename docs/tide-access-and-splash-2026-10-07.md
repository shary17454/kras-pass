# Tide Access, Spawn Symmetry and Splash Qualification

Repository: shary17454/kras-pass; remote origin.
Branch: fix/kras-tide-accessible-steps.
Parent: 2e38decfde1894e71309e288286e18001836d694 (PR 164).
Final runtime/test source: 323612bb3425b94901be886a646c9630809248f5.
Engine: Godot 4.7.1 official a13da4feb.
Runtime fingerprint: 6b249a3558eac969a8a43f9146977386d0cfe2d9a3acfe601a3a0e6c284062dd.

## Implemented

- Tide-only recipe: step height 1.1m, summit gap 1.1m, eight ledges per
  tier. Every ledge has a 90-degree rotated counterpart. The unrelated
  duel pit retains default heights 2.3m/9.1m and counts 7/8/9.
- Four explicit floor spawns avoid the old elevated ledge overlaps.
- Climber observes actual solid box/cylinder top surfaces, not decorative
  rings or geometry-free markers. Target height respects ordinary character
  jump impulse and gravity. Prefer adjacent steps over maximal-height leaps.
- AI creates approach room, brakes its outward movement before jumping,
  uses an ordinary full movement stick and slows near the landing point.
  It waits for floor contact before a first plan and replans after landing.
  No invented center-at-spawn-height destination remains cached.
- Observation delay, current visibility, instance identity and legitimate
  last-observed route memory remain tested. No hidden movement is read.
- Splash ring is added to the tree before global positioning and fades
  through GeometryInstance3D transparency, not nonexistent modulate:a.
  Existing splash audio, particles and timed ring cleanup are retained.

No character speed, jump, stats, damage, scoring, timer, save schema,
network protocol, signing identity or production account data changed.
The AI stick remains bounded by the same movement physics as a human.

## Corrected Defect Interpretation

The prior isolated vertical probe measured all eight apices below the old
first surface and was interpreted too broadly as no first-step access for
any character. Actual Fighter.tick input and landing tests are stronger:
seven characters fail the first tier; ghaim reaches two tiers but fails
the third. Thus no character completes the old full route in the corrected
test, but the earlier all-eight first-tier statement is not retained as fact.

Initial red/green fixtures forgot to enable control after setup. Their
failures at y=0 are not defect proof: /tmp/kras-tide-step-red.log and
/tmp/kras-tide-step-green.log. Corrected pre-recipe regression: 11 passed,
eight failed, 2.6s; /tmp/kras-tide-step-corrected-red.log.

Early AI fixtures also exposed approach, decorative-ground and spawn-plan
failures. One used nonexistent TestHarness.approx, causing fixture errors
and unclean exit; it was corrected to near, not treated as game evidence.
Retained intermediate logs: /tmp/kras-tide-step-ai.log,
/tmp/kras-tide-step-ai-speed.log, /tmp/kras-tide-step-ai-settle.log,
/tmp/kras-tide-step-spawn.log and /tmp/kras-tide-step-safe-spawn.log.

## Final Focused and Rendered Evidence

- Permanent physical regression: 123 assertions passed, 4.1s;
  /tmp/kras-tide-symmetric-final.log. All eight characters land on four
  consecutive tiers with ordinary input, without inter-tier teleports.
  Expert route planning then reaches the summit from each of four actual
  spawn points for every character. The route fixture disables attacks,
  water and camera filtering deliberately; it is not natural-match proof.
  Quarter-turn symmetry, solid reachable selection, disabled jump capability
  and unchanged duel-pit heights are asserted.
- Delayed-ground regression: 81 passed in 1.2s on the candidate logic;
  /tmp/kras-tide-perception-final.log. Fixtures were upgraded to real box
  colliders with reachable heights, retaining visible positive and hidden,
  transparent, offscreen, replacement and timing negatives. Final full gate
  reruns this suite on final source.
- Visibility suite: 3997 passed, 5.6s;
  /tmp/kras-tide-visibility-capable.log. Its old Node3D climbing markers
  became actual reachable colliders; the borrowed non-jumping fighter's
  jump capability is enabled only for this fixture and restored afterwards.
- Actual Compatibility rendering: Arabic, one touch human plus three bots,
  landscape 1280x720 and portrait 540x960 after ten seconds. Both captures
  passed the strict runtime-log guard and were manually viewed. Log:
  /tmp/kras-tide-symmetric-visual-ar.log. Images:
  /tmp/kras-tide-symmetric-visual-ar/screenshots/.
  This is not native iOS, max text scale, four physical humans or all-map QA.
- Earlier visual smoke printed PASS but emitted two actual splash errors
  per capture: not-in-tree transform and nonexistent modulate:a. Retained:
  /tmp/kras-tide-safe-visual-ar.log. Those images are not accepted as a clean
  runtime result. The strict guard on corrected captures has no such errors.
- Explicit rendered splash probe verifies location, intermediate fade and
  post-animation ring release: /tmp/kras-tide-splash-check-drained.log,
  terminal exit 0 and strict guard pass. Temporary source/scene:
  /tmp/kras-tide-splash-check.gd and .tscn. First probe parse failure retained
  in /tmp/kras-tide-splash-check.log. First successful animation probe still
  exited with mixer references: /tmp/kras-tide-splash-check-final.log, not
  final acceptance. Using the project's AudioManager.shutdown/two-frame/
  mixer-buffer drain at fixture teardown produces the final clean result.
  Compatibility AA warning remains visible and is not an iPhone AA test.

## Natural Campaigns

Each final campaign completed 24 baseline, 16 mirrored same-character
difficulty matches and two mutator/chaos matches with real camera, water,
ordinary inputs and physics. Both exited 0 with strict log guards. Start
and end source fingerprints equal the final fingerprint above.

| Seed offset | Expert edge | Slot bias | Character bias | Tie rate | Avg seconds | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 600000 | 0.713483146067416 | 0.15 | 0.075 | 0.208333333333333 | 12.175 | none |
| 900000 | 0.705882352941177 | 0.0743243243243243 | 0.118243243243243 | 0.333333333333333 | 11.5472222222224 | none |

Reports: tide-access-natural-600000.json and tide-access-natural-900000.json.
Logs: /tmp/kras-tide-symmetric-natural.log and
/tmp/kras-tide-symmetric-independent.log.
Independent seed offset 900000 was not used to choose the geometry change.
These are limited samples, not 1000 matches or universal balance proof.
Short 11-12s averages still need party-flow/gameplay review; no READY label
or all-39 qualification is inferred from these campaigns.

Retained development campaigns were not silently discarded:
dc84a558437e50689e19aac5b013a9d7469dd2fa had 54% ties, expert edge 0.58031;
/tmp/kras-tide-access-natural.log. Its fingerprint was
0ccb0b5a4aff7636ab14c6d77f0604cfcfd3d02b3308411238c933f07d864ec3.
c0ab243a2374fa0b1f912cdec6acdc5b7150d58a had spawn advantage (bias
0.233870967741935), 25% ties, expert edge 0.688235;
/tmp/kras-tide-safe-natural.log. Its fingerprint was
0c07cdf6a104b2b18cb3b13524f280757916dd63a9730f8146ca82d483f55785.
No thresholds, seeds, scoring or character strengths were relaxed to remove
these flags. The c0ab full gate was intentionally stopped for this further
fix, exit 130: /tmp/kras-tide-safe-full.log. It is not a complete pass.

## Final Full Gate

tools/check_party.sh completed on final runtime/test source, terminal 0:
409 scripts compile; 502 resources, 22 autoloads, 27 routes, eight characters,
zero inventory issues. 384546 assertions passed in 334.6s. Three-lap race
and six boss probes passed. Stability: 39 matches, zero failures. Material,
mesh, texture and audio PCM caches drained to zero; settled memory after
five seconds was 139786753 bytes. Log: /tmp/kras-tide-symmetric-full.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.29CJFx.
Intentional negative-test diagnostics and the known sandbox macOS CA access
diagnostic remain retained. This single cycle is not sustained FPS, thermal,
battery, physical-device or long-term leak qualification.

Server: 204 passed, zero skipped/failures, 758.397208ms, terminal 0;
/tmp/kras-tide-symmetric-server.log. All six actual world-schema captures
came from this full gate's saves-tests directory, not previous sources.

Four actual Godot clients plus a localhost WebSocket server completed a
45-second capped scripted tide fixture, seed 609001. Every client agreed
on scores [4,4,4,4]; guest and host reconnected. Guest world snapshots:
975, 994, 994. It is agreement on a tied fixture, not natural winner/balance
proof or four physical humans. Maximum recorded server loop delay 69ms,
not a passed latency target. Log: /tmp/kras-tide-symmetric-network.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-l2cCQ3.
No Internet, production authentication or Railway acceptance is inferred.

## Remaining Release Gates

No main merge, Railway deployment, new Version/Build, signed Archive,
App Store upload, processing or review submission occurred. No P12 import,
password request, certificate change or production data export occurred.
Fresh full-source all-game balance/perception/polish, physical iPhone/iPad
orientation and sustained performance/gameplay, authorized source promotion,
approved protected backup/restore/migrations and production protocol rollout,
production API/auth/Internet acceptance, actual ASC login/inventory and a
fresh exact-source local Xcode 27 Distribution Archive remain required.
The active whole-project objective is not complete.
