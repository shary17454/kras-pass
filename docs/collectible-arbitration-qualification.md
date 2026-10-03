# Collectible Arbitration Qualification

Base: world-camera branch head `e66fa8c1c190e753c18dd21c82b94dbd26f1c330`.
Implementation: `853f589`.

## Observed problems

`Collectible.tick` awarded a pickup to the first eligible body in the physics
overlap array, not the nearest body. Equal-distance selection therefore also
depended on the engine's overlap enumeration order rather than the match seed.

Crate Relay rejected a pickup after emitting `taken` when its selected player
already carried cargo. The item became available again, but the same overlapping
carrier could win that first-body selection again next tick, denying a nearby
eligible player. Capacity must be checked before arbitration.

## Implementation

- Select the nearest alive eligible overlapping fighter.
- Retain dropped-loot owner grace and reject invalid bodies.
- Sort exact-distance co-candidates by stable player slot before a seeded draw,
  so physics body ordering does not affect the draw's meaning.
- Consume no arbitration RNG for a unique winner or empty candidate set.
- Skip candidate-array allocation for an empty overlap list.
- Pass the existing authoritative match RNG from Gem Grab, Star Rush,
  Crate Relay and Relic Hold. Crate Relay also passes its cargo eligibility rule.
- Retain the old one-argument `tick` API for compatibility. Without an RNG an
  exact tie has a stable slot-order fallback; all four production collectible
  callers now provide the match RNG. Future games must do the same.
- Emit only one successful pickup; normal pool release, scoring and authority
  remain owned by the existing minigame callback.

No save or network payload schema changed. Seeded arbitration changes simulation
behavior; this does not promise identical outcomes for old recorded matches
across gameplay revisions or different engines/platforms.

## Evidence

Godot 4.7.1, temporary save directories and explicit log files:

| Check | Result | Log |
|---|---|---|
| Original first-body selection, mechanically extracted into a selector | 7 passed / 807 failed, exit 1 | `/tmp/kras-pickup-baseline.log` |
| Final arbitration and actual Crate Relay overlap | 821 assertions passed, exit 0 | `/tmp/kras-pickup-final.log` |
| Collection host/guest contracts | 99 assertions passed, exit 0 | `/tmp/kras-pickup-collection-network.log` |
| Relay round/reset/pool lifecycle | 34 assertions passed, exit 0 | `/tmp/kras-pickup-relay-rounds.log` |
| Relic Hold lifecycle | 47 assertions passed, exit 0 | `/tmp/kras-pickup-relic.log` |

The 800 fixed-seed tie checks compare opposite body orders using identical RNG
seeds, then check each slot receives opportunities. They are arbitration
regressions, not 800 naturally completed matches or a character-balance proof.

The actual overlap fixture puts two full carriers inside an authored crate's
Area3D and confirms no rejected pickup signal is emitted. It then empties one
carrier, confirms exactly one accepted cargo transfer despite the closer full
carrier, checks pool retirement, and checks no repeat pickup on later ticks.

Repository log guards passed for these suites. `git diff --check` passed.
363 tracked/new Godot scene/script/resource, data and project inputs were
byte-compared against the owned warm runtime with zero mismatch. This does not
qualify generated native iOS files, assets, a PCK, signing or a release archive.

## Remaining qualification

Main `132f83d` natural campaign `37148818784` yielded a validated partial
snapshot of 14/39 games and 588 completed matches, with six balance signals.
Gem Grab had slot-bias 0.2142857; this observation prompted inspection, but it
does not prove first-body arbitration caused that entire measured bias.
Run a source-matched natural sample after this fix before claiming it resolves
the signal. Do not relax balance thresholds or discard poor results.

The previous camera head passed clean-checkout core CI (28607 assertions,
325 scripts, 117 stability matches and 179 server capture checks); those
results do not qualify this later collectible commit. A fresh full core and
peer matrix are required. Physical device/input/orientation/frame-pacing,
battery/thermal, production networking and signed-source release gates remain
open. This branch has not been merged to main or uploaded to Apple.
