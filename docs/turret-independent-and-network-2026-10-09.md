# Independent turret balance and completed network evidence

No runtime code or balance thresholds changed in this batch.

## Turret Duel independent cohort

Clean source b5e4f9e7d61c3dedbb6e79b6741ebf86f57a9c69, fingerprint
53cde46b50cf16a86a63439072b716dfbf475238dfca1ef42a671d5bc384b552.
Natural, original-duration Godot simulation, fixed-fps 60, --runs=64,
--only=turret_duel, --seed-offset=8600000, isolated saves. Exit 0;
strict stdout check passed, source start/end match.

Completed 64 baseline matches, 32 difficulty comparisons and two mutator/chaos
matches: 98 total. Independently checked all 16 paired seeds, character
rotation, swapped Expert slots, completed outcomes and recalculated the
placement-based Expert metric from all 32 samples.

| Cohort | Slot winner counts | Expert metric | Tie rate | Flags |
|---|---|---|---|---|
| Previous 8000000, 24 baseline | 13 / 5 / 6 / 2 | 0.64 | 0.083333 | spawn slot advantage |
| Independent 8600000, 64 baseline | 17 / 17 / 24 / 19 | 0.657738 | 0.140625 | none |

Shared first places make winner-count totals exceed baseline match totals;
these counts are not exclusive single-winner probabilities. Mean independent
duration is 105.334896 seconds. No round clipping or hidden AI/stat buff.
The new cohort does not erase the previous warning or prove every map/spawn
balanced. It does not justify a blind nerf to slot zero.
Raw report and logs: ../qualification-turret-independent-860-2026-10-09/.

## Previous all-game network campaign completed

Run 37932029724 completed successfully: Core plus all 39 game scenarios;
the balance job was intentionally skipped. Downloaded artifacts have 40
distinct scenarios, all attested to cae51363c2190a32ee79a57ded8929fcd4e26d05,
matching intended head, no tracked changes. All 1235 downloaded stdout/log
files passed the repository checker with the proper import/tests/runtime modes.
Raw evidence: ../qualification-network-cae-complete-2026-10-09/.

This is older-source localhost evidence, not the current candidate or Railway.
After it became terminal, new full network run 37950626662 was dispatched on
b5e4f9e7d61c3dedbb6e79b6741ebf86f57a9c69. Current balance run 37950278256 uses
the same source, seed offset 8300000. Both remain incomplete at this inspection.
No live campaign was cancelled/restarted. No main merge, production mutation,
device installation, upload, App Review submission or new stage DONE.
