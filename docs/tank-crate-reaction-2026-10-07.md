# Tank Crate Observation Qualification - 2026-10-07

## Scope and Source

- Repository: `git@github.com:shary17454/kras-pass.git`, remote `origin`.
- Branch: `fix/kras-tank-crate-reaction-delay`.
- Parent: `b3224c5bebff7f4709149a2737f72d78b913ad83` (PR 165).
- Runtime fix: `fade7346bcaec03711faa7c1d2f73ea94369d962`.
- Final test/source commit: `942036af6c0a00733e94eac8be61979d8d53fb7c`.
- Godot: `4.7.1-stable (official)`, a13da4feb.
- Simulation source fingerprint: `67ed39f6d5c714fc5262914ed0f9975df5f23d384a17b1a8b0bbdd092f5f50fa`.

## Defect and Fix

Tank AI previously selected a newly visible weapon crate and navigated to its
live transform immediately, bypassing every difficulty profile's reaction time.
The corrected regression against the original implementation produced 33 passes
and 28 failures: `/tmp/kras-tank-crate-corrected-red.log`.

`src/ai/brains/tank_brain.gd` now records visible, unobstructed available crates
by instance identity, retains at most 32 position samples per crate, and selects
and steers using the position observed at the configured reaction delay. History
is removed when a crate becomes hidden, occluded, collected or unnecessary to an
armed player. Respawn/reappearance requires fresh observation credit. Configure
and round restart clear both crate history and routing state.

The production character, speed, ammunition, shell damage, timers, scoring and
network protocol are unchanged. No balance thresholds were relaxed.

## Tests and Retained Failures

- New `tests/suites/test_tank_crate_perception.gd`: 93 assertions, terminal exit 0,
  `/tmp/kras-tank-crate-final.log`; strict log guard passed. Tests cover all four
  configured delays, delayed navigation positions, disappearance, reappearance,
  occlusion, collection/respawn, armed inventory, reset and bounded storage.
  An actual `StaticBody3D` obstruction also blocks acquisition through the real
  raycaster. The timing fixture separately controls visibility/ray results; it
  does not prove every camera/orientation or physical input path.
- Existing AI visibility suite: 3997 assertions, terminal exit 0,
  `/tmp/kras-tank-crate-visibility.log`; strict log guard passed.
- First whole gate failed: 384633 passed, 5 failed in the old tank steering
  fixture, `/tmp/kras-tank-crate-full.log`, evidence `kras-party-check.SLgvtv`.
  The fixture assumed immediate acquisition. The test-only follow-up explicitly
  sets its delay to zero to isolate steering/availability. All four real profile
  delays remain independently asserted in the new suite.
- Corrected tank network/steering suite: 165 assertions, terminal exit 0,
  `/tmp/kras-tank-crate-network-suite.log`.
- Initial invocation without `--log-file` crashed while opening a sandboxed
  user log, exit 134. Another early fixture omitted assigning its controller,
  producing Nil calls. Neither run is used as defect or acceptance evidence.

## Final Whole Gate

`GODOT_BIN=/opt/homebrew/bin/godot sh tools/check_party.sh`, terminal exit 0.

- Log: `/tmp/kras-tank-crate-qualified-full.log`.
- Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.ynOuXc`.
- 410 scripts compile; 503 resources, 22 autoloads, 27 routes, 8 characters,
  zero inventory issues.
- 384638 assertions passed in 222.2 seconds.
- Separate three-lap race and six boss probes passed.
- Stability: 39 matches, zero failures. Material/mesh/texture/PCM caches released;
  settled five-second memory 139805564 bytes. One cycle is not a long leak test,
  physical-device FPS, battery or thermal qualification.
- Server: 204 passed, zero skips/failures, 777.292708 ms,
  `/tmp/kras-tank-crate-server.log`, using all six actual world fixtures from this
  successful run. Local socket execution was explicitly escalated.
- Known sandbox macOS CA-read diagnostic remains; no SCRIPT ERROR acceptance.
  The harness intentionally tests negative empty-suite fixtures separately.

## Natural Matches and Local Network

Natural tank campaign: `/tmp/kras-tank-crate-natural-900000/report.json`, raw copy
`docs/tank-crate-natural-900000.json`; stdout `/tmp/kras-tank-crate-natural.stdout`.
Terminal exit 0; strict log guard passed. 24/24 baseline matches, 16/16 mirrored
same-character Easy/Expert comparisons, two successful mutator/chaos probes.
150-second original window; average duration 114.692361111114 seconds; Expert
placement share 0.61875, slot bias 0.07, character bias 0.115, ties 1/24, flags []
at the existing thresholds. This limited sample is not universal balance proof.

Start/end simulation fingerprints match. The test-only steering commit was made
while this campaign ran: the fingerprint covers src/scenes/data/tools/project,
not tests. Runtime simulation inputs did not change; the complete whole gate was
then rerun with the final test commit.

Four actual Godot processes and localhost WebSocket server: terminal exit 0,
`/tmp/kras-tank-crate-network.log`, evidence `kras-network-smoke-H5MhmB`.
All four clients agreed on scores `[925,930,1000,945]`; guest ID 2 and host ID 1
reconnected. Guest world/snapshot counts 1708,1689,1708; max server loop 87 ms,
without a performance acceptance threshold. This uses scripted inputs and a
30-second duration override, not natural balance, four physical humans, native
Apple authentication or a Railway Internet test.

## Release Gates Still Open

No main merge, production deployment, version/build change, signed local Xcode
27 archive, App Store upload, processing or App Review submission occurred.
The live Chrome check still redirected ASC to `authResult=FAILED` after the user
reported login. Other AI brains and all-game current-source qualification,
physical iPhone/iPad controls/performance, authorized backup/restore and
production rollout remain separate unfinished requirements. No P12 import,
password request or certificate creation/revocation was performed.
