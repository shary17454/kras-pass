# Keeper Visible Arrival Priority

Runtime source: `e3be323` on `fix/kras-keeper-arrival-priority`, based on
`41e025a7bb770fd7e846c6b6ab2181bd597fa4e2`. No main integration or production
deployment follows from these checks.

## Problem and Change

The shared keeper selected balls by heading and distance, without accounting
for time to its shield. A near slow ball could displace a farther shot arriving
much sooner. The regression reproduces this on all four goal sides: the
unchanged implementation passed 21 assertions and failed 4. An earlier test
draft failed to parse because a dynamically typed controller required an
explicit Vector3 annotation; this was a test-authoring error, not game evidence.

The keeper now prioritizes the earliest observed incoming shot crossing its
playable shield lane. It retains the previous fallback when no observed shot
is approaching that lane. The contact geometry matches the existing sphere and
shield interception calculation. Only delayed observed position, velocity and
rendered radius are used; hidden/departing/wide-miss shots cannot outrank a valid
incoming goal threat. Difficulty profiles, movement, character stats, scoring,
round windows, magnet mechanics and report thresholds were not changed.

## Focused Verification

| Suite | Result |
| --- | --- |
| keeper_contact_plane | 25 assertions passed |
| ai_visibility | 2091 assertions passed |
| magnet_network | 190 assertions passed |
| goal_guard | 144 assertions passed |
| storm_network | 178 assertions passed |
| compile check | 394 scripts compiled |

All completed with exit 0 and their strict log checks passed. Evidence paths
use `/tmp/kras-keeper-arrival-*`, including retained red and green stdout/logs.
These focused suites do not replace a fresh full source-wide regression run,
rendered human QA or real Internet multiplayer.

## Natural Before/After Comparisons

Each cohort and version completed 24 baseline rounds, 16 mirrored matched
seed/character difficulty rounds and 2 mutator/chaos rounds: 168 matches total.
Baseline source was the detached checkout at `48a17ea` (same runtime as the
parent), not a manually patched or truncated game. Godot 4.7.1 and the same
existing fixed-step natural simulation runner were used for both versions.
Both mutator checks passed in all four reports, and all strict runtime log
checks passed. No winner was injected and no time window was reduced.

| Seed offset | Before Expert rank share | After Expert rank share | Before flags | After flags |
| --- | ---: | ---: | --- | --- |
| 1500000 | 0.519230769230769 | 0.533653846153846 | expert bots no better than easy | none |
| 1800000 | 0.533653846153846 | 0.528846153846154 | none | none |

The original cohort reproduced the Linux campaign value exactly on macOS.
The independent cohort declined slightly; do not claim uniform improvement,
population confidence or a win-rate increase. Correct threat prioritization is
proved by the targeted reproduction, while broader difficulty balance remains
sample-dependent. No READY classification is asserted.

Start/end simulation fingerprints match within every run:

- Before: `af354bc49e94b6c247269af1ca05bf5d4e0c263566d23fefae5b82fb49920813`.
- After: `2d3e970ae4f962679d4025f9ed32ce0fa693b870492f16e9e0b4c61aa51a4072`.

Reports are in `/tmp/kras-keeper-arrival-{baseline,after}-{natural,independent}-report/report.json`.
The live full 39-game campaign `37484382887` targets the earlier source and
does not qualify this new keeper code. Do not cancel or relabel its results.

## Remaining Gates

Full regression/network qualification of this source, the shared keeper games'
wider balance, all-game campaign review, portrait/landscape human play, device
performance and thermal/battery checks, coordinated server/client production
rollout, exact-source signing/archive/upload/processing/App Review remain open.
The previously compiled iOS app predates this change and must be rebuilt before
any release claim.
