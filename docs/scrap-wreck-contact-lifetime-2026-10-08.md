# Scrap wreck contact lifetime

Source: `29c0c79a655a150dd28ea0885151fce77b2d2508`.
Parent: `3ed6a7fbc10805b2055d339ba060c10177ada5ee`.

## Reproduced issue

`_resolve_rams` checked the outer kart's life only before entering its pair loop.
Backwash could eliminate it in the first pair, yet the next pair still treated
its position as a ram collider. Elimination correctly zeros the kart's velocity,
so the first stationary-third-kart fixture passed and did not prove a defect.
When a third kart approached the now-dead collider, the real match fixture
reproduced damage from its backwash, a new pair cooldown, and duplicate ram
feedback: seven assertions passed and three failed.

The third kart lost health from 100 to 93.8285714285714 even though the other
kart had already been eliminated. This is a collision-lifetime defect, not proof
of the cause of the observed Easy/Expert balance warning.

## Fix and scope

Before each subsequent pair, stop the outer pair loop if its kart was eliminated.
The first live collision retains its damage/backwash/feedback. Mutual damage
within that collision is not interrupted. A healthy kart still processes both
nearby live collisions. No AI profiles, speed, damage budget, balance threshold,
sample window, controls or network schema changed.

## Verification

- Contact lifetime: 13 assertions pass, including the new dead/healthy cases.
- Existing Scrap network/damage presentation suite: 121 assertions pass.
- All 422 scripts compile.
- One current-source stability cycle: 39 matches, zero failures, cache release
  completes after the deliberately injected memory warning.
- Existing log guards pass for both completed test suites, compilation, natural
  simulation and stability. No logs were edited and no guard was weakened.
- Natural sample: 24 baseline, 16 paired difficulty, two successful stress
  matches. Seat wins `[4,10,5,5]`, Expert edge `0.50625`, ties zero. These match
  the earlier sample: `expert bots no better than easy` remains and is retained.
- Official Godot `4.7.1-stable`; simulation start/end fingerprint both
  `ef891f443408c595f6440a9e3d5d4dec8dc41fb1008be8e05894cf92e94ac524`.

The parent full gate's 390616 assertions and real Magnet network match do not
constitute a fresh full gate or four-client Scrap match for this new source.
Those broader checks, further balance work and device acceptance remain open.
No all-games READY claim, main merge, Railway mutation, archive, upload or
App Review submission was performed.

## Evidence

- Initial stationary diagnostic: `/tmp/kras-scrap-wreck-red-engine.log` (passes).
- Reproduced moving-third failure: `/tmp/kras-scrap-wreck-moving-red-engine.log`.
- Final regression: `/tmp/kras-scrap-wreck-complete-engine.log`.
- Existing network suite: `/tmp/kras-scrap-wreck-network-engine.log`.
- Compilation: `/tmp/kras-scrap-wreck-compile-engine.log`.
- Stability: `/tmp/kras-scrap-wreck-stability-engine.log`.
- Natural engine log: `/tmp/kras-scrap-wreck-1200000-engine.log`.
- Raw report: `docs/qa/scrap-wreck-contact-2026-10-08/natural-1200000.json`.
