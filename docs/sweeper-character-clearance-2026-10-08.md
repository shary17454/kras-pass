# Physical character jump clearance

New registered regression suite: test_sweeper_character_clearance.gd.
It uses the real Fighter, character/perk tuning, StaticBody3D floor and
Sweeper Area3D/mesh at the authored 0.85 height. It does not replace collision
physics or change character stats, AI delays, hazard strength or balance gates.
All eight characters start grounded inside the blade's horizontal extent,
jump from an actual input edge, physically clear the blade and land again.

Targeted suite: 42 assertions passed, exit 0 and strict log guard passed.
Full registered regression run: 392787 assertions passed in 173.1 seconds,
exit 0 and strict log guard passed. Its raw log and stdout are retained with
the targeted evidence below.
Observed conservative clearance samples require both no Area3D overlap and
fighter origin more than 1.2 above the floor. These are fixed 60 Hz samples,
not exact continuous-time clearance intervals or a guarantee of AI timing.

| Character | Actual apex above floor | Conservative clear seconds |
| --- | ---: | ---: |
| nabta | 1.984 | 0.500 |
| sakhra | 1.721 | 0.400 |
| fanoos | 1.930 | 0.483 |
| ramla | 1.823 | 0.433 |
| barq | 1.930 | 0.483 |
| mowja | 1.877 | 0.450 |
| ghaim | 2.465 | 0.617 |
| turs | 1.772 | 0.417 |

The earlier natural campaign's heavy-character win advantage cannot be
explained simply by a longer stationary jump-clearance window: sakhra's
measured window is shortest. This does not establish the cause of win bias;
moving encounters, impact exposure, recovery, AI timing and arena shrink still
need evaluation. No character is certified balanced by this test.

Raw targeted logs retained at
../qualification-sweeper-character-clearance-2026-10-08/.
Known local macOS system CA certificate diagnostic is present; the test guard
passes but these logs are not described as entirely ERROR-free.
This test-only change does not modify shipping runtime inputs. The ongoing
network run 37834212081 remains pinned to 47d33475d7e93a33eb82b4c4a3d48ad0e8c6626a;
it does not automatically include this later suite. No iOS archive, Railway
promotion, upload or App Review submission happened as part of this test.
