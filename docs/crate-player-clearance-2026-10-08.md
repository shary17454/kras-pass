# Crate Smash: Live Player Spawn Clearance

Parent: `27452db50076887d6f0dc1fd78c2168707253185`.
The previous placement check rejected other crates but accepted a candidate
inside a live player's body, including an enlarged capsule.

The check now rejects horizontal capsule-to-crate-box overlap plus a 0.1
clearance margin for live players. It reads the actual CapsuleShape3D radius,
so size effects affect occupancy. It reserves the projected landing space of
airborne players too. Eliminated players do not reserve spawn space. This
game uses walking capsule bodies; missing shapes use the existing 0.42 base
radius. It does not claim generic vehicle collision clearance.

The existing bounded search and deferred retry remain unchanged. No new
physics queries, per-frame spawning, character boosts, scoring, save or
network protocol changes were added. This addresses unsafe appearance, not
proven causation of a sampled spawn-slot win advantage.

## Verification

- Before fix: 167 assertions passed and two failed, reproducing acceptance
  through normal and enlarged live bodies. Exit one:
  `/tmp/kras-crate-player-before.stdout`.
- Final-source crate/network suite: 169 assertions, exit zero, strict tests
  guard passes. Tests also retain bounded failure/retry behavior and confirm
  ordinary distant space remains usable and eliminated players are ignored.
  `/tmp/kras-crate-player-final.stdout`.
- All 429 scripts compile with strict log guard:
  `/tmp/kras-crate-player-compile.stdout`.
- Natural sample: 24 baseline, 16 mirrored difficulty and two smoke rounds
  completed at seed offset 3900000. Strict runtime guard passes. Start/end
  source fingerprints match:
  `3c4a6722c287b7c486e51f875ee80350949c5fe06eaa37bf814f90e795bfb746`.
  Expert share 0.6706586826, slot bias 0.0833333333, character bias
  0.1666666667; no automatic flags in this small sample. Both stress modes
  completed. `docs/qa/crate-player-clearance-2026-10-08.json`.

Core run 37765555402 still belongs to the earlier Color AI source 8c52fb3;
its result must not be attributed to either later crate fix. Full current
qualification, retained balance warnings, physical-device playability and
performance, production deployment and exact-source local Xcode archive
remain open. Native UI inventory still reports the Mac locked. No production
changes, Apple upload or review submission occurred.
