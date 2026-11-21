# Duel Pit matched alternate-arena comparison

## Source

Clean parent commit `a007715b36b701e0ec163135715c1f15f35baf48`, branch
`feature/kras-online-random-rotation`; gameplay remains fingerprint
`adbbda6d74c6f6d6fb5f508ec50970e3123381f34a38f28329759d57b75ad1dd`.
Godot 4.7.1-stable (official), isolated imported runtime
`/tmp/kras-tank-pursuit-check`. No runtime, tests, physics, stats, AI or acceptance
thresholds changed. The source proof does not attest all assets or a native build.

## Controlled comparison

Compared the previous 80000000 default-pit sample with the same seeds/rosters on
the registered alternate arena `iron_flats`. All 96 baseline seeds and complete
baseline roster arrays match exactly. Each character appears 48 times.

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-iron-matched-80000000.engine \
  tools/balance_sim.tscn -- --runs=96 --only=duel_pit --arena=iron_flats \
  --balanced-rosters --seed-offset=80000000 \
  --out-dir=/tmp/kras-duel-iron-matched-80000000-report \
  --test-data-dir=/tmp/kras-duel-iron-matched-80000000-save
```

96 natural baseline + 48 matched/mirrored difficulty + two mutator/chaos smoke
instances completed: 146, terminal exit 0, elapsed report time 344.1 seconds.
Both smoke cases pass. Both original stdout/engine logs pass the unchanged
runtime guard. Start/end source fingerprints match the checkout/runtime source.
There was no concurrent owned qualifying simulation.

This uses supplementary `seeded_partition_seat_rotation`, not canonical
`adjacent_rotation` qualification. The arena change includes geometry, walls,
pillars, radius and their effect on AI perception/decisions; it does not isolate
one scalar parameter or preserve identical realized inputs after the start.

## Measured results

| Metric | Default pit 80000000 | Iron Flats 80000000 |
| --- | ---: | ---: |
| Sakhra baseline credited wins | 30 | 14 |
| Character bias | 0.1875 | 0.0280612244897959 |
| Seat bias | 0.104166666666667 | 0.0561224489795918 |
| Expert point share | 0.636182902584493 | 0.506024096385542 |
| Mean natural duration | 63.6923611111088 s | 95.8550347222181 s |
| Baseline ties | 0 / 96 | 2 / 96 |
| Zero-score baseline matches | 0 | 0 |
| Flags | character advantage | expert bots no better than easy |

Iron Flats character credited wins: Barq10, Fanoos11, Ghaim14, Mowja11, Nabta15,
Ramla11, Sakhra14, Turs12. Seat credited wins: 30,24,18,26. Both totals are 98,
not 96 matches, because tied results credit shared winners.

The previous held-out default-pit sample at 84000000 also flagged character
advantage with Sakhra26. All original warnings remain retained. The alternate
arena is not clean: it replaces the character warning with a difficulty signal.
This is not an all-arena balance pass or READY promotion.

## Architectural inspection and next action

Fighter._apply_character uses effective movement/combat tuning and small perks;
the existing effective-budget suite checks values within 15 percent of neutral.
That static budget does not prove game-specific balance. Default pit geometry
has three ledge tiers; Iron Flats is a bounded disc with pillars. DuelBrain uses
observed damage to choose rivals, retreat/dash near edges, and melee attacks.
These behaviors interact differently with the two arenas.

Fighter._apply_hit also subtracts health and can emit knocked_out before a
ring-out, whereas the Duel source comment describes damage as launch scaling
rather than lethal health. The localized rules describe accumulating damage and
three knockouts. This is a contract question to resolve with an actual match
fixture before changing health semantics; no unverified fix is claimed here.

The next investigation is game-specific: trace actual fall/health knockout
causes, collision/spawn behavior and AI engagement on both maps. Do not weaken
Sakhra globally or remove a playable map merely because one report is greener.
Use measured failure and narrow regression tests before changing gameplay.

## Evidence and release gates

Raw original alternate-arena report JSON/HTML and both logs:
`../qualification-duel-arena-pair-2026-10-10/`. Paired original default reports:
`../qualification-duel-independent-2026-10-10/`.

The comparison above predates the separate [spawn clearance correction](arena-spawn-clearance-2026-10-10.md).
Its source was not changed while that comparison ran. The correction changes
spawn data and records new full-suite/compile evidence under its own source.
No main merge/push, production migration/deploy, new native archive, upload or
Apple submission. Physical human/controller/device and production release gates
remain open. Stage 0 is QA_PENDING/MERGE_PENDING; later stages remain locked.
