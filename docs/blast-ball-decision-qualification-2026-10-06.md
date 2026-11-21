# Blast Ball Decision Qualification

Runtime source: `3cb8a398e5b77e389da6c0865844bec3bd8ac036`, based on
`f9aed05d2e6d05d372f7bafd789140a05a6859be`. This is a feature branch,
not an integrated main release, signed archive or App Store submission.

## Retained Changes

`b2eef1152bf7902470cb0dc9ae21130adca3150b` reserves the own fighter's
walking travel time to the existing strike range before committing to an
offensive approach. Only delayed observed position/fuse and own movement
parameters are used. Long-fuse and already-in-range attacks remain possible.
The targeted reproduction failed one assertion before the change and passed
98 afterward.

`3cb8a398e5b77e389da6c0865844bec3bd8ac036` replaces unsafe bomb-escape edge
correction with bounded safe lateral candidates. The previous correction
steered toward an observed bomb at each of the four cardinal rim positions.
The red run passed 102 assertions and failed four; the green run passed 106.
Existing difficulty awareness and arena geometry govern the candidate search.

No character statistics, human controls, ball physics, scoring, ordinary round
window, difficulty profiles or balance-report thresholds were changed.

## Qualified Source Checks

The retained runtime passed the Blast Ball suite (106 assertions), shared AI
visibility suite (2091), compilation (394 scripts), and the 39-game one-cycle
stability run (39 matches, zero failures). Each completed with exit zero and
its strict Godot stdout guard passed. Evidence uses the prefixes
`/tmp/kras-blast-edge-*`.

Actual localhost server plus Godot peer processes passed both network cases
in `/tmp/kras-blast-edge-network.stdout` with seed 1504242:

- Two human input processes plus two bots: matching scores `[10,12,10,12]`.
- Four human input processes: matching scores `[16,10,12,10]`.

Movement and the designated host/guest reconnection were verified; the other
two peers were not designated reconnect subjects. The maximum observed server
loop delay was 109 ms under local concurrent testing, not an FPS, Internet
latency or production acceptance result. These processes are not four real
people using touch/gamepads. The older parent's full 366313-assertion run does
not qualify this changed runtime as a fresh full regression.

## Natural Balance Evidence

Every report completed 24 baseline rounds, 16 mirrored matched-seed/character
difficulty rounds and two mutator/chaos rounds. All five retained source
comparisons below passed the strict runtime log check: 210 completed matches.
No winner was injected and the existing 90-second ordinary round window was
not shortened.

| Seed offset | Before | Travel only | Travel and safe rim escape |
| --- | ---: | ---: | ---: |
| 1500000 | 0.465838509316770 | 0.459627329192547 | 0.493750000000000 |
| 1800000 | 0.465838509316770 | not run | 0.468750000000000 |

Values are Expert rank-point shares, not win rates. Every report retained
`expert bots no better than easy`; no READY classification or solved balance
is asserted. The travel-only candidate declined in the original cohort.
The final source improved on its baseline in these two limited cohorts but
still failed the unchanged difficulty policy.

Reports are `/tmp/kras-blast-approach-{baseline,after}-natural-report/report.json`,
`/tmp/kras-blast-edge-natural-report/report.json`, and
`/tmp/kras-blast-{baseline,edge}-independent-report/report.json`.
Final source fingerprint matched at start/end in both final reports:
`8868eb51766155703a7e5ab3b7381ad4ca7efc65415aad81c74d471b60dd08c0`.

## Rejected Contact-Dash Experiment

An additional uncommitted candidate suppressed AI escape dashes inside the
existing three-unit strike range. GameBall's active deflection biases the
ball toward the dashing fighter's facing; a fleeing contact can send the ball
along the escape path. The policy reproduction failed four assertions before
the candidate (110 passed), then passed 114 afterward. An initial command used
an invalid suite suffix and selected no suite; it is not game test evidence.

Despite the targeted green result, natural difficulty evidence declined:
0.49375 to 0.4625 at offset 1500000, and 0.46875 to 0.44375 at offset 1800000.
Both candidate reports retained the difficulty flag, completed all 42 matches,
passed mutator/chaos checks and strict runtime log guards, and matched source
fingerprint `cceba5f23f0a89f4886b788f2f91b34ea1a371b8edced078af51cc6f61433e66`
at start/end. Reports use `/tmp/kras-blast-contact-{natural,independent}-report`.
This candidate is rejected, not a shipped improvement. Its passing targeted
test is insufficient to justify weaker natural gameplay.

The candidate also completed a full local gate: 394 scripts, 439 resources,
366333 passing assertions, race and six boss probes, and 39 stability matches
with zero failures. Log: `/tmp/kras-blast-contact-full-gate.stdout`; detailed
outputs: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.KvbmGK`.
This passing gate belongs to the rejected candidate, not the restored runtime.

## Remaining Gates

Blast Ball difficulty balance remains open. All-game immutable balance/network
CI, rendered portrait/landscape human QA,
physical iPhone performance/battery/thermal tests, production server/client
protocol coordination, and exact-source signed local Xcode 27 archive,
upload, processing and App Review remain separate uncompleted gates.
No main merge, Railway deployment or Apple submission follows from this report.

## Final Restored-Source Full Gate

The rejected candidate and its eight new assertions were removed with a scoped
patch after its processes completed. `git diff` against the retained runtime
is empty for both changed gameplay/test files. A new full run then completed
with exit zero on runtime `3cb8a398e5b77e389da6c0865844bec3bd8ac036`:

- 394 scripts compile; 439 resources, 22 autoloads, 27 routes, eight characters,
  zero inventory issues.
- 366325 assertions passed in 218.6 seconds.
- Race regression and all six boss probes passed.
- 39 stability matches, zero failures; all strict stage log guards passed.
- Main log: `/tmp/kras-blast-retained-full-gate.stdout`.
- Detailed outputs: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.XNtcrw`.

All six actual world captures from this restored-source run were supplied to
server `npm test`: 193 passed, zero failed and zero skipped. Log:
`/tmp/kras-blast-retained-server-fixtures.stdout`. The iOS source-evidence
Python suite passed 12 tests and export-log Node suite passed four. Dependency
audit reported zero advisories; this is not a full security assessment.

The release-input inspector accepted committed inputs and reported SHA256
`500887f878f6907acf0c1da5abf2e357c3842ab54c763b73e44b83e56721b63a`.
This is source inspection, not a current exported pack or signed Archive.
Local Keychain still contains the requested Apple Distribution identity for
team 4HM66AD594; no P12 was imported or certificate changed. Xcode 27's current
device inspection still reports the physical iPhone unavailable. Live production
health responds with `ok=true`, `authentication_ready=true`, and
`multiplayer_enabled=false`; no production rollout occurred.
