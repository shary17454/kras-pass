# Current Source Network And Rendered Performance Evidence

Runtime source: `7f270c506650ea8dbe780df539fc0d316bdddf4a`, tree
`30c5384cff9628fa8048d7a52945930fd814d86f`, runtime fingerprint
`160a0600b0616ed7e26dc2706782afdec832130ea902dd46caf3fb20ab7af1c1`.
Local performance probes ran from documentation-only descendant `d273307`;
Git diff against the source is empty for src, data, native and project.godot.
Evidence: `qa/current-network-perf-2026-10-08/`.

## Current CI Evidence, Not Full Matrix Completion

Run 37730081774 uses workflow_dispatch, not a PR merge checkout. Inspected
source manifests for core, ring_rumble, goal_guard, gem_grab, star_rush,
zone_hold and relic_hold: exact intended/checkout commit and tree, expected
run ID, clean tracked source. All seven match the source above.

Core reports 391990 passing Godot assertions, 238 passing server tests with
all six actual Godot world captures, zero skipped server capture tests, and
117 stability matches across three cycles and all 39 default arenas. Each
match reports zero failures and 51 post-cleanup nodes. This stability fixture
uses four AI and shortened timed rounds; race laps remain unchanged. It is
not sustained physical-device memory or all-player/all-map QA.

The full Godot suite retains intentional failed-write and router-load error
fixtures. Its successful assertions are not a claim of error-free raw logs.

All six completed networking scenarios contain successful ordinary matches
and tournaments for both two and four actual engine peers, driven by scripted
input. Host and client reconnect are reported in every group. Every peer's
tournament result is complete; these runs exercise natural tie handling too:
relic_hold resolves one tiebreak, star_rush resolves two in its two-peer group,
zone_hold resolves one in its two-peer group. Ring Rumble exhausts three tie
attempts and safely returns four co-champions; it does not produce a unique
winner on this fixture. Preserve that limitation instead of calling it a
unique-winner acceptance test. Zone Hold also passes its contest regression.

Other jobs are still queued/running. These seven artifacts do not qualify the
remaining 33 games, public Internet latency, physical users or production
Railway connectivity. No job was cancelled or restarted in this evidence pass.

## Four-View Tank Probe

Godot 4.7.1 official, Metal Forward Mobile, Apple M5 Mac, tank_oasis, seed 72,
540x960 window, actual 405x720 root render target, quality 2, cap 60, four
personal views sharing one simulation. Four scripted touch-driving slots,
zero bots, no firing. Existing imported resources/shader caches were reused.
This is not a cold-start or weapon-heavy benchmark.

| Probe | Steady duration | FPS | p95 ms | p99 ms | Worst ms | Frames >50ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Without trace | 60.006 s | 58.694 | 20.628 | 33.012 | 80.745 | 7 |
| With trace | 30.012 s | 58.010 | 20.474 | 33.472 | 106.549 | 10 |

Both complete their requested duration, exit zero and pass the existing
strict runtime log guard. Nodes return from 51 to 51. Raw memory readings
include retained caches; node equality is not proof of zero memory leakage.
The first three seconds of the longer probe contain a 267.109 ms frame.

Trace retains slow CharacterBody3D movement intervals at RockCover11,
RockCover14 and TerrainCollision, up to 15.407 ms per fighter physics call;
match.fighters reaches 25.047 ms. These are inclusive wall intervals, not
exclusive CPU/GPU costs. Do not sum parent/child times or attribute every
whole-frame stall solely to one collider. Prior rejected box/chunk experiments
remain rejected; no collision geometry, visual quality or gameplay rule was
changed to improve these numbers.

Stable 60 FPS is not established. Physical iPhone/iPad frame pacing, battery,
temperature, controller play, final content quality, production deployment,
positive native production connection, signed local Xcode 27 archive, upload,
processing and App Review submission remain open. Chrome sign-in was verified
live; it is not evidence of an upload. No production or Apple state was changed.
