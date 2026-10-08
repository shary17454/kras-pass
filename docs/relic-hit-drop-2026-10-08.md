# Relic hit-drop correction

## Defect

Relic Hold declares that a hit drops the relic and that its carrier cannot
attack. The controller previously handled falls and knockouts but never
subscribed to the shared `player_hit` event. A normal accepted melee/body hit
therefore left the carrier holding and scoring until actual elimination.
This broke the intended steal/counterplay rule; faster carriers dominated the
expanded natural sample. The defect is established independently of whether
it fully explains the balance warning.

## Correction

The controller now subscribes once during build, drops the relic on a positive
accepted hit against the current living carrier, and disconnects during
cleanup. Shield-break cues have zero strength and do not drop it. Fighter
invulnerability continues to suppress accepted hits. Self-hit cues are ignored.
Environmental hits drop it without crediting a rival. Repeated cues after the
drop cannot duplicate the relic or award a second steal.

No character stats, AI parameters, scoring cadence, score/win conditions,
round duration, seeds or balance thresholds were changed. This uses the shared
Fighter damage event, as the existing Crate Relay controller already does.

## Regression evidence

Source: parent `8408c358743e55db7382e0ad1439011681724fe3` plus the two-file
controller/test patch in this commit. Generated QA files and this document do
not change the simulation source fingerprint.

- Test against old controller: 55 passed, six failed, specifically for normal
  hit-drop, cargo, attack permission, loose-item availability and steal credit.
  The first fixture attempt also produced null follow-on errors; the retained
  clean RED run checks the missing object and stops dependent assertions.
- Corrected controller: all 65 relic assertions pass, including existing
  snapshot validation and guest presentation/scoring-authority checks.
- Shared pickup perception: all 406 assertions pass.
- Compile: all 425 scripts pass.
- All passing logs pass the existing strict guard, including leak diagnostics.
- Four actual local Godot peers plus a real WebSocket server: PASS, scores
  `[2,2,1,5]` agreed on all peers; host and guest reconnected. Guests consumed
  1088/1107/1107 authoritative world snapshots. Every engine log passes the
  strict import-mode guard. This scripted smoke test uses existing short test
  match settings; it is not natural-duration four-human or Internet QA.

## Natural balance samples

| Sample | Baseline | Difficulty | Offset | Character bias | Expert share | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| Before fix | 96 | 48 | 2800000 | 0.1979167 | 0.6488706 | character advantage |
| After fix | 24 | 16 | 2900000 | 0.0833333 | 0.6913580 | none |

Each also completed two mutator/chaos rounds. Both used official Godot 4.7.1,
natural round windows, distinct baseline seeds, matched seed/character mirrored
difficulty pairs and unchanged start/end source fingerprints. Before fingerprint:
`164f48a0f380b3540864b51503d45b31a0666a284a4433b78e896ad0f4295f1d`.
After fingerprint:
`ac045b0218697a2f7ee8e6ef32d38906d8c69487f9faa6657dda9af0cfaa57f6`.
The after sample finished 42 total matches in 135.6 seconds with exit zero;
baseline slot wins were `[5,6,7,6]`, with no ties.

Different seed offsets and sample sizes are not a matched causal comparison.
The small after sample is promising, not proof that the earlier expanded
warning is fully resolved. Expanded held-out qualification remains required.
The before sample is preserved, not replaced or reclassified as passing.

Evidence directory: `docs/qa/relic-hit-drop-2026-10-08/`.

## Release state

The previous source's Linux core run 37751547974 succeeded with 392340 Godot
assertions, 243 captured-world server tests and a four-peer mixed tournament.
It predates this fix and is not full qualification for this new source.
No main merge, Railway production change, new Xcode archive, upload, review
withdrawal or submission occurred. Device/performance/production and broader
product acceptance gates remain open.
