# Tank Ammo Perception Qualification

Runtime source: `07d81f753938e0205f01018c4aeb5e5f35df122b`.
Branch: `feature/kras-tank-visible-ammo`, based on main `7b617be`.

## Corrected Behavior

Tank AI previously selected the nearest stored crate coordinate before checking
line of sight. An occluded crate could suppress a reachable crate. No visible
rival also prevented ammunition gathering entirely.

The controller now exposes available rendered crate nodes, excluding hidden,
inherited-hidden, collected, invalid and queued nodes. The brain selects the
nearest observable crate with a clear ray within the existing 30-unit radius.
It can collect without a visible rival, still shoots while moving toward ammo
when a rival is available, and gives edge recovery priority. The compatibility
`crate_target` helper uses rendered positions instead of hidden stored positions.
Human inventory, projectile rules, ammo rewards and network schema are unchanged.

## Verified Checks

- `/tmp/kras-ammo-confirmed-baseline.log`: the corrected test fixture against
  main's original tank scripts fails nine assertions, with no GDScript errors.
- `/tmp/kras-ammo-final.log`: 154 tank/network assertions pass, exit zero.
- `/tmp/kras-ammo-ai.log`: 119 AI observation assertions pass, exit zero.
- `/tmp/kras-ammo-compile.log`: all 324 scripts compile, exit zero.
- 361 tracked source/data/test/tool files and project.godot match the runtime
  checkout byte-for-byte before the final test. No source changed during it.
- `git diff --check` passes.

An intermediate test fixture omitted `brain.controller = game`, causing nil
controller errors. It was corrected and the baseline and final runs were both
repeated; that intermediate failure is not evidence of a production defect.
Godot logs retain the macOS system CA retrieval warning.

## Remaining Gates

Campaign `37108335239` completed all 39 simulation jobs successfully on older
source `0b21cac95075705a3ee85641e33e3aa680bcd879`. It does not test this fix and
uses unpaired difficulty comparisons. Its warnings require review, not blind
retuning or an automatic READY label. A fresh paired campaign, full current-source
regression, physical-device performance/layout QA and Apple release validation
remain required. This change is not an Archive, upload or review submission.
