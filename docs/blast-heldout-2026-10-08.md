# Blast Ball Held-Out Balance Sample

Source commit: `f00420e` on `feature/kras-online-random-rotation`.
Godot 4.7.1 official, fixed simulation rate 60, seed offset 3600000.
No gameplay or acceptance thresholds were changed for this sample.

The local run completed 96 baseline matches, 48 mirrored Expert/Easy
same-seed/same-character comparisons and two smoke matches, exit zero.
The strict runtime log guard passes. Simulation fingerprints match before
and after: `051fc839dabff190a0a0873a7caa81b2f419384ec9f48f4347473a3e9a4252f0`.

Results: Expert placement-point share 0.525; slot bias 0.0625; character
bias 0.0520833333; baseline slot wins `[23,22,30,21]`. All 48 difficulty
comparisons completed. Mutator and chaos samples both completed without
flags. The automatic report has no balance flags for this sample.

This does not erase campaign 37754749544's earlier 16-comparison warning
at seed offset 3000000 (Expert share 0.45625). The larger held-out sample
is narrowly above the unchanged 0.52 acceptance threshold and is not
proof of robust population difficulty separation or a causal bug fix.
Retain both samples; do not tune against these seeds then call them held out.

Evidence: `docs/qa/blast-heldout-2026-10-08.json`.
Log: `/tmp/kras-blast-heldout-96.stdout`.
This is not all-game, physical-device, network, battery or iOS release
qualification. No archive, upload, processing or submission occurred.
