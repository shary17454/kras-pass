# Lab spawn failure regression

## Confirmed defect and scoped repair

During review of the Lab character-bias warning, inspection found a separate
spawn failure defect. The parent crate spawn can return without appending a
crate after twenty unsuccessful placement attempts. The Lab override still
indexed the last crate and tried its weapon-promotion logic. With an empty
list this raised an out-of-bounds script error; with an existing normal crate
it consumed an extra gameplay RNG draw and could promote the wrong crate.

The override now records the previous crate count and returns if the parent
did not append a crate. No character stats, scoring, spawn-clearance rules,
network packet formats, save schema or acceptance thresholds changed.

`test_crate_network.gd` adds an exhausted-placement probe covering an existing
crate's data/visuals, parent-only RNG consumption, an empty list, absence of
orphan nodes and successful retry when space becomes available.

## Before and after

- Before: targeted suite exit 1, 178 passed / 1 failed (unexpected RNG draw),
  plus the reproduced out-of-bounds index `-1` in the Lab spawn override.
- After: targeted suite exit 0, 179 assertions; strict completed-tests guard PASS.
- Full suite: exit 0, 408180 assertions in 209.7 seconds; strict test guard PASS.
  The full suite includes deliberate negative-path error/warning messages;
  this is not a claim that every logged line is error-free.
- Compile check: exit 0, all 450 scripts compile; runtime guard PASS.

## Independent natural Lab sample

After the repair, 96 baseline matches + 48 mirrored difficulty comparisons +
two mutator/chaos smoke matches completed: 146 instances, exit 0 in 261.9 seconds.
Godot `4.7.1-stable (official)`, default Lab arena, four AI players, seed offset
`48000000`. Natural baseline/difficulty window: declared 90 seconds; smoke
uses its existing shorter window. Both smoke modes and strict runtime guard PASS.

Pre/post/current source fingerprint:
`be7952428ad72f69703dfa8d918427c7d8e42e1466d5007445c0a527c16316dd`.
Recorded seeds, counts and paired seed/character comparisons were checked.
Under `seeded_partition_seat_rotation`, each character appears 48 times,
twelve times per seat. Warnings: none; Expert point share 0.667992,
slot bias 0.041667, character bias 0.083333; average duration 90.329 seconds.

This is supplemental independent-roster evidence, not canonical acceptance.
The previous 24-match character-bias warning stays documented. The different
source and seeds do not prove this spawn repair caused a balance improvement.
The earlier all-39 fingerprint `c6997498...` cannot qualify this new source.
Current-source all-39 canonical/network/device acceptance remains required.

## Evidence and release status

Persistent original failure and successful logs, and natural JSON/HTML:
`../qualification-lab-spawn-2026-10-10/`.
Temporary originals: `/tmp/kras-lab-spawn-{before,after,full,compile}.stdout`
and `/tmp/kras-lab-spawn-natural-report/` with corresponding engine logs.

Local feature commit only. No main merge/push, production migration/deployment,
native archive rebuild, App Store upload or review submission. No READY/DONE
promotion or claim of iPhone performance, thermal behavior or production online QA.
