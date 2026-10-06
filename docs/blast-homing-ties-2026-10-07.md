# Blast Ball Homing and Explosion Tie Fairness

Base: `815570d136e8a69542ceeaba1ea8c5e14a8f1203`, the unified release
qualification branch. Runtime change:
`d8faa3cad3db392ac05cac20e7c04a298e6bf5d8`, on
`fix/kras-blast-homing-ties`. This is not main or an Apple release.

## Defect and Change

Blast Ball's authoritative `_nearest_alive_to` previously returned the first
live slot whenever distances tied. Both homing and explosion victim selection
use this helper. The final equally nearest live candidate set now uses the
existing seeded match RNG. A uniquely nearer candidate replaces earlier ties;
unique and empty candidate sets do not consume RNG. Dead or invalid fighters
remain excluded. No AI perception, difficulty profiles, character speeds,
attack strength, scoring, physics, fuse or round window changed.

The reproduction uses four equal-radius real match fighters, one eliminated
slot, 256 choices and a repeated seed. It also verifies unique and empty
candidate behavior and restores all positions, alive flags and RNG state.
Red: 367 passing assertions, three fairness failures. Green: 370 passing
assertions, zero failures. This validates the helper contract, not general
balance or deterministic real-time replay.

## Checks on Changed Runtime

- Blast Ball suite: 370 passing assertions.
- AI visibility suite: 3962 passing assertions.
- Compile: 396 scripts, all compile.
- One-cycle stability: 39 matches, zero failures.
- Strict log guards for these completed checks passed.

Logs: `/tmp/kras-blast-homing-{red,green,visibility,compile,stability}.log`.
The macOS CA certificate diagnostic remains an environment diagnostic, not
a clean-import claim. Stability deliberately emits a simulated memory warning;
cache release is not physical-device or long-duration leak acceptance.
The parent's full suite is not a fresh full regression of this runtime.

## Natural Matched Comparison

Before and after each completed 24 baseline, 16 paired difficulty and two
mutator/chaos matches at offset 900000 with the unchanged 90-second round
window. All log guards passed. Fingerprints were stable at start/end:

- Before: `275da44d2b7f40fc80368e2a84f4b9388d3b01349c170df70aada963629af1c3`.
- After: `d7f877fa7b4a16c2d6c29ee8a038aa39dcd8209048f98b0494fdc444a87f015c`.

Both report Expert rank-point share 0.48125, slot bias 0.0833333333333333,
character bias 0.0416666666666667, zero ties and the retained warning
`expert bots no better than easy`. The limited natural cohort does not show
an improved difficulty result. The defect fix is retained for explicit
equal-distance fairness; it does not qualify Blast Ball as READY.
Complete generated reports are committed alongside this document.

## Network Acceptance

Actual localhost WebSocket service plus Godot processes completed on this
runtime (seed 909001), exit zero:

- Two human-input processes and two bots: matching scores [8,4,14,16].
- Four human-input processes: matching scores [16,12,10,16].
- Designated host/guest disconnect and reconnect passed in both cases;
  the other two peers were not reconnect subjects.
- Four-client guest world snapshots: 1088, 1107 and 1107.
- Maximum local server event-loop delay: 49 ms.

These are scripted processes, not four physical human players, a production
Internet session or physical-device FPS/battery/thermal qualification.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-3GtXJK`.

## Remaining Release Gates

Expert balance, all-game current-source quality/perception acceptance,
physical iPhone/iPad QA, approved promotion, production backup/restore and
protocol rollout, native production auth and gameplay connection, frozen
Version/Build and exact-source local Xcode 27 Distribution Archive, signing,
upload, processing and separate App Review submission remain incomplete.
No main merge, Railway change, certificate import or Apple upload was done.
