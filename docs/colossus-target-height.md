# Colossus Target Height and Pilot Recovery

## Evidence Leading to Changes

- Diagnostic repeat before fixes:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-LdR0KP`.
  It failed at the peer deadline. The logs show that simulation advanced into
  round 1; this was not an indefinitely stuck first round. Damage occurred, but
  neither observed round recorded defeat. Server loop maximum was 6220 ms.
- Corrected pilot run before target-height fix:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-DfHWVJ`.
  The first round ended with boss health 195, so the strengthened fixture failed
  immediately instead of awaiting another round. This is not online qualification.
  Server loop maximum was 1727 ms; host preparation/frame maximum was 4379 ms.

## Reproduced Defects

1. A fighter-safe crater rim can have 0.45 clearance while the pilot path requires
   0.5. Every candidate then failed at its starting point, freezing the pilot.
   `/tmp/kras-colossus-pilot-rim-before.log`: 142 pass, one failure.
2. Boss target selection checked horizontal ground but retained arbitrary fighter
   height, including a parked fighter at y=-500. Jumping warnings remained above
   the deck, and the buried fist assumed world floor y=0.
   `/tmp/kras-colossus-target-height-before.log`: two pass, ten failures.

## Fixes

- Pilot escape permits a path from reduced positive clearance only if its endpoint
  regains the navigation margin and intermediate samples never reduce initial
  clearance. Missing crater ground still prohibits movement.
- Ordinary real-peer qualification fails as soon as a round ends without defeat.
- Boss selection rejects nonfinite positions and fighters below the actual floor.
  Eligible jumping targets project onto the arena plane. Hidden, dead, eliminated,
  outside and above-hole fighters remain excluded.
- Buried fist position is one unit above its actual target plane, not fixed world y=1.
- Actual peer diagnostics reject warnings off the arena plane.

## Regression Evidence

- Pilot and shared-world suite: `/tmp/kras-colossus-pilot-rim-after.log`, 152 asserts.
- Final target-plane suite: `/tmp/kras-colossus-target-height-final.log`, 12 asserts.
  One intermediate run used exact Vector3 equality for a rotated translated pose;
  it failed on submillimetre transform precision. Final test uses distance <=0.001,
  which still rejects the original seven-unit height error.
- Shared-world suite after runtime fix: `/tmp/kras-colossus-height-network.log`,
  152 asserts. Real capture, guard authority, round reset and reconnect remain valid.
- Actual four-Expert-bot regression: `/tmp/kras-colossus-height-ai.log`, seed 9614,
  defeated=true, health=0, scores [275, 220, 110, 220]. This is one local AI seed,
  not broad balance or real online peer qualification.

No boss health, damage, attack timing, exposure window or ordinary duration changed.
The target-height defect can affect push direction, but this does not prove every
large impulse or scheduling stall is fixed. Real peer qualification and performance
measurements must be rerun after this checkpoint.
