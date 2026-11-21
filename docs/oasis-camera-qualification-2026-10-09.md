# Oasis Vehicle Camera Qualification

Base: `7d0750ec739a22daeaf58a8849bb22a85edbfa6b`, feature branch
`feature/kras-online-random-rotation`. This is a runtime camera fix, not a
release acceptance or production deployment.

## Reproduction And Fix

The natural four-human `tank_arena` / `tank_oasis` fixture, seed 250925,
settles from its elevated spawn onto the ground. P2's sightlines at 0.3 and
0.6 metres then hit `RockCover13`, while its 1 and 2 metre rays clear it.
The initial frozen-spawn test missed the defect; allowing real physics for
144 frames reproduced two failing assertions. No cover, collision mesh,
character stats, scoring, input or match rules changed.

Close WORLD follow cameras now test the low vehicle footprint, excluding the
followed body's RID. They try up to eight raised positions before falling back
to the existing close obstacle recovery. Footprint samples include all four
corners, not just the character head or vehicle centre. At most 45 rays are
queried per obstructed close camera update; unobstructed updates use five.
This bounds the work but is not a physical-device performance measurement.

## Evidence

- Focused world camera suite: 906 assertions, exit 0.
- Full suite: 406421 assertions, 356.9 seconds, exit 0.
- Both completed test logs pass `tools/check_godot_log.sh` in tests mode.
- Real local Metal capture: two captures, portrait 540x960 and landscape
  1280x720, four human touch slots, two additional seconds of live physics,
  zero capture failures, exit 0. Both final images manually inspected: the
  vehicle footprint is visible without the close-up crop.
- Final visual engine log passes the runtime log checker.
- `git diff --check` passes.
- Runtime fingerprint before and after full regression:
  `879ddd3bd82bebf03430f1b74fc98c0255c2e7ac949f598fbfb977be84c5e86f`.

Evidence retained at `../qualification-oasis-camera-2026-10-09/`.
All intermediate captures are retained: the first recovery exposed a close-up
crop, and subsequent centre/side checks still missed part of the footprint.
The first test attempt had a fixture type-inference parse error; the first
green fixture omitted explicit teardown and logged leaked resources. These
were corrected, not described as qualifying passes. The final focused and
full test logs pass the strict leak/error checker. Known macOS CA and negative
save/harness diagnostics remain in full raw logs.

## Still Open

The existing bc46d4e signed archive and IPA do not contain this fix. A fresh
source-proven archive is required before upload. Existing network campaign
37970339411 and balance campaign 37971414154 target d9841d2, not this runtime;
both were still queued when checked, and were not cancelled or restarted.
This fixture does not qualify all map positions, long-running camera motion,
physical controllers, iPhone/iPad FPS, battery or heat. Production backup and
restore authorization, migration/deployment qualification and actual native
production connectivity remain separate gates. No main merge, production
change, App Store upload or review submission occurred in this fix.
