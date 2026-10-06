# Colossus Contestable Opening Qualification

Runtime source: `7318794558b13020421f19b2e815dfe4f7ea05a0`.
Branch: `balance/kras-colossus-contestable-opening`.
The preceding diagnostic-only commit is
`7d3706fabb99e1ddcabc00946b3671df09ac6c99`; its runtime matches PR117.

## Controlled Change

Arm exposure increases from 2.4 to 3.2 seconds for every input source.
Health remains 800, arm damage 55 and one hit per player per opening.
Hazard timing, geometry, AI reaction/lapses and character stats are unchanged.
Godot replica and server validators accept the new upper bound; tests accept
0, 2.4 and 3.2 and reject 3.21. No synthetic victory is recorded.

## Matched Natural Simulation

Each cohort has 24 medium-difficulty baseline matches, rotating the eight
characters through slots, within the authored 150-second maximum. Additional
paired difficulty and mutator checks run separately from the baseline counts.

| Seed offset | Old defeats | New defeats | Old mean seconds | New mean seconds |
| --- | --- | --- | --- | --- |
| 600000 | 2/24 | 23/24 | 147.7361 | 120.8160 |
| 900000 | 3/24 | 18/24 | 148.0125 | 127.2951 |

Reports: `/tmp/kras-crater-route-natural-report/report.json`,
`/tmp/kras-colossus-opening-baseline-b-report/report.json`, and
`/tmp/kras-colossus-opening-cohort-{a,b}-report/report.json`.
The second old/new reports have identical baseline seed arrays. Empty balance
flags do not establish fairness: cohort A has two characters with zero wins,
and cohort B slot wins are [3,3,12,9]. Further contribution/spawn testing and
human play are required. Status remains NEEDS_BALANCE, not READY.

## Completed Checks

- Full gate: 366204 assertions, 392 scripts, resource validation and 117
  stability matches pass. Settled static memory is 133617588 bytes after cache
  release; this is not a physical-device memory or battery measurement.
- Server: 192 passed, zero failed/skipped, using real Godot world fixtures.
  The Colossus fixture contains an exposed value of 3.2.
- Real local network clients: 2 humans/2 bots and 4 humans pass score/world
  replication and guest disconnect/reconnect. Inputs are automated, not four
  people. Maximum server loop delay reached 224ms under concurrent test load;
  no latency or production performance acceptance is claimed.
- Native macOS Metal: portrait and landscape captures after 10 seconds are
  nonblank and manually inspected; runtime stdout guard passes. No iOS device
  gameplay/FPS/thermal test was performed.
- Old baseline import exited zero but emitted sandbox CA/editor-settings
  diagnostics. It is not a clean import qualification; its completed gameplay
  stdout runtime guard passes.

Logs: `/tmp/kras-colossus-opening-release-gate.stdout`,
`/tmp/kras-colossus-opening-server.stdout`,
`/tmp/kras-colossus-opening-network.stdout`,
`/tmp/kras-colossus-opening-native.log`, and
`/tmp/kras-colossus-opening-baseline-b.stdout`.

## Release Gates

Production server still rejects exposure above 2.4. Deploy matching server
validation before enabling this online gameplay. Protocol remains 1: an old
guest rejects a new host's 3.2 snapshot even though a new server accepts old
hosts. A version/capability compatibility policy is required before online
activation; mixed-version compatibility is NOT established by these tests.

Live App Store Connect on October 6 shows version 1.1.10 build107 Ready for
Distribution. TestFlight also contains completed build108 for version1.1.8.
Neither proves these new sources were uploaded. No existing release was
withdrawn or modified. Future archive/upload must use local Xcode27, a new
available build number, frozen integrated source, and the existing matching
Distribution identity/profile. No main merge, Railway deployment, new archive,
upload or App Review submission was performed during this qualification.
