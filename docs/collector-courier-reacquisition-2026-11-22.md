# Collector And Courier Reacquisition

Baseline: 132867501f04c19f667fe6aa71a848e43a2b9416.
Branch: fix/collector-reacquisition-20261122.

## Gameplay Fixes

Collector competition previously required visibility and historical knowledge,
but not continuous-sight reaction credit. After a rival disappeared and returned,
Hard and Expert could immediately reprice pickups using old knowledge. Target
selection now requires can_target(), retaining the delayed observation contract.
Easy and Normal keep their existing non-competitive pickup policy.

Courier carrier selection previously required only a live rival. Delayed cargo
memory survived an interruption in visibility, permitting premature pursuit when
the rival reappeared. Selection now requires can_target(); delayed cargo and
position history remain intact and mature normally after reacquisition.

Neither fix changes speed, damage, character stats, reaction parameters, save
schema, or online authority. Both use the existing shared perception gate.

## Regression Evidence

All four difficulty tiers are exercised with positive reaction delays. Tests
cover initial observation, occlusion between history samples, reappearance,
pre-threshold decisions, exact-threshold decisions and resumed pursuit or pickup
competition. Courier additionally checks that cargo remains delayed.

- Collector: 8 regression failures before the change; 48 assertions pass after.
- Courier: 16 regression failures before the change; ai_visibility has 4652
  passing assertions after the fix.
- Godot: 4.7.1 official a13da4feb, local macOS, isolated test saves.

These are regression results, not character-balance acceptance or device FPS,
thermal, battery, touch, or Duo gameplay certification. Uploaded build 113 is
older than these changes and must not be submitted as containing them.
