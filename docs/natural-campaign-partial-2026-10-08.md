# Natural Campaign: Partial Review

Run: `37754749544`, source `1c52aae9abcac5a963c75ce5072e3b7a08a7f469`.
Seed offset: 3000000. Godot: 4.7.1 stable official.
This is historical gameplay-source evidence, not qualification of the latest
native UI, development probes or a release archive.

The downloaded immutable snapshot contains 37 of 39 reports, with 1554
completed natural matches: 24 baseline, 16 mirrored difficulty comparisons
and two smoke matches per game. The campaign remains live; `drift_floes`
and `duo_clash` are absent from this snapshot. Do not restart the campaign
because their reports are not downloaded yet.

The existing report verifier accepts each available report's checkout,
commit, run identity, engine, unchanged simulation fingerprint, seeds,
completion and difficulty pairs. Whole-campaign source consistency and
difficulty pairing remain unqualified until all 39 reports are present.

Retained warnings:

| Game | Warning |
| --- | --- |
| blast_ball | Expert bots no better than Easy |
| scrap_karts | Expert bots no better than Easy |
| boss_forge | Spawn slot advantage |
| color_stand | Spawn slot advantage |
| crate_smash | Spawn slot advantage |
| ring_rumble | Spawn slot advantage |

These are sample-based review flags, not established causal defects. Larger
held-out Ring Rumble evidence exists separately and must not overwrite this
sample. The independent 96-match Sweeper character warning also remains open,
even though this smaller campaign sample has no Sweeper flag.

Boss baseline objectives were defeated in 21/24 Colossus, 24/24 Dreadnought,
24/24 Forge and 22/24 Sovereign runs. All four bosses' mutator/chaos samples
ended as survival rather than defeat. Completing a match is not the same as
defeating its objective.

Evidence snapshot: `/tmp/kras-campaign-37754749544-snapshot-38`.
Machine summary: `docs/qa/natural-campaign-partial-2026-10-08.json`.
Full campaign review, targeted reproductions, device performance, production
online acceptance and exact-source local Xcode archive remain required.
No production changes, archive, upload or Apple submission occurred.
