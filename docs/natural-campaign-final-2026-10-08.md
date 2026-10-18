# Completed Natural Balance Campaign

Run `37754749544` is terminal `success`: 41 jobs completed, none failed.
Source: `1c52aae9abcac5a963c75ce5072e3b7a08a7f469`.
Engine: official Godot 4.7.1. Seed offset: 3000000.

All 39 downloaded reports pass the local campaign verifier without partial
mode. The resulting JSON exactly matches CI's downloaded campaign summary.
There are 1638 completed matches: 936 baseline, 624 mirrored difficulty and
78 mutator/chaos samples. Checkout identities, seeds, completion, source
fingerprints and all paired comparisons are verified. No report is missing.

This supersedes only the completion status of the earlier partial snapshot,
not its warnings or evidence. Six warnings remain:

- `blast_ball`, `scrap_karts`: Expert bots no better than Easy.
- `boss_forge`, `color_stand`, `crate_smash`, `ring_rumble`: spawn slot advantage.

CI success means execution/evidence integrity passed. The summary explicitly
retains `balanceReviewComplete=false` and `releaseReady=false`. Do not convert
these sample warnings into READY status or dismiss them as test failures.
The independent larger Ring and Blast samples remain separate evidence;
the independent Sweeper warning remains open even without a campaign flag.

This source predates native pause UI and expanded development probes. It is
not current-source whole-product qualification or an Apple archive. Current
tests, visual/device gameplay, thermal/energy acceptance, production online
rollout and exact-source signed Xcode 27 release remain separate gates.
No production environment or Apple state changed in this verification.

Summary: `docs/qa/natural-campaign-final-2026-10-08.json`.
Raw reports: `/tmp/kras-campaign-37754749544-snapshot-38` (directory name is
historical; it now contains all 39). CI summary:
`/tmp/kras-campaign-37754749544-final-summary/balance-summary.json`.
