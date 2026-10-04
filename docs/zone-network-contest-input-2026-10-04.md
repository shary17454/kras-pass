# Zone Network Contest Input

Baseline: `f29824f82d6f34d6d5e4b090befa17e792be6f94`.
Linux networking job `111348417037` failed with seed 438683058 and zero scores.
The identical Mac baseline seed completed with scores `[1,0,3,1]`, so the Linux
failure is not claimed reproduced or fixed by a Mac pass.

The human peer fixture previously routed around the capture band without ever
pressing attack for this game. Uncontested occupancy is required for points;
movement alone does not exercise the supported contest-clearing mechanic.

`tests/zone_peer_driver.gd` retains the peer's arc pursuit and uses annular
waypoint routing. Once inside, it approaches the nearest living visible
contestant, presses attack only within 2.1 units and facing them, and releases
between 700-ms attack pulses. This is ordinary `InputFrame` input, passed through
the existing router and authoritative game simulation. No score, position,
damage, bot behavior, game rule or pass assertion is overridden. The distinct
slot pursuit offsets remain test behavior, not a product balance prescription.

Fresh focused tests: 4673 assertions, positive completion and log guard.
Compilation: all 332 scripts, log guard passed. Source for the live peer run:
`ecf84b6` (the later workflow/document edits do not change its game/test scripts).

Actual same-seed process groups passed:

- Two humans plus bots: both peers `[2,0,2,0]`; restored identity and 1088 client
  world snapshots.
- Four humans: all peers `[25,0,0,0]`; the disconnecting client restored identity;
  the other clients observed 1087/1107/1107 world snapshots.

Logs: `/tmp/kras-zone-peer-input-tests.stdout`,
`/tmp/kras-zone-contest-compile.stdout`, and
`/tmp/kras-zone-contest-network-438683058.log`.
The server loop maximum was 7260 ms. Therefore these runs are not evidence of
acceptable latency, Internet play, physical performance or fair slot win rates.
The driver deliberately pursues different paths; its scores are not a balance
sample. Four real human users and production Internet play remain unqualified.

The same failing seed is now an additional permanent `zone_hold` Linux CI check
for both peer counts. Existing random ordinary/tournament checks remain intact.
Linux qualification is pending; no assertion was removed or weakened and no
Apple archive, upload or review submission is claimed.
