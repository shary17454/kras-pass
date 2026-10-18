# Seeded Nearest-Rival Tie Selection

Base: `dc2477cb46acc4ebad9eee3b5675b275b1fb4374`.
Branch: `fix/kras-nearest-rival-ties`.

## Confirmed Issue

The common AI nearest-rival scan retained the first eligible slot when multiple
visible opponents were equally close. The 900-choice regression selected only
the smallest rival ID before the fix. This is a targeting-order bias, not proof
that it explains all measured spawn advantages.

The scan now collects only final equally nearest candidates and chooses among
them using the brain's existing seeded random generator. Unique final nearest
targets consume no randomness, including when earlier scan entries had tied.
Self, hidden and eliminated rivals remain ineligible. Positions still come from
the existing delayed perception layer; no current hidden-state access is added.

## Focused Evidence

- RED: 3924 passed / 3 failed in AI visibility suite.
- GREEN: 3927 assertions passed.
- Tests cover eligible target distribution, same-seed reproduction, unique
  closest-target priority, RNG preservation and hidden/eliminated exclusion.
- Log: `/tmp/kras-nearest-rival-green.log`.
- Godot log guard and git whitespace checks passed.

## Integration Regression

The existing `test_matches.gd` suite completed with 6960 assertions passed in
278.1 seconds. It covers completion paths for all 39 games, aggregation, pause,
restart, controller loss, mirrored difficulty fixtures for collection/crates,
armor/cover, elevated routes, rescue penalties and three real AI laps in every
registered Rocket Rally arena. Its ordinary matches use the suite's shortened
windows; the natural balance samples above are separate evidence. This is not a
full-suite run, network-peer run or physical-device performance measurement.

Log: `/tmp/kras-nearest-rival-matches.log`; strict log guard passed.

## Two Natural Scrap Karts Samples

Godot 4.7.1-stable official a13da4feb, macOS. Each sample completed 24 natural
baseline rounds, 16 mirrored same-seed/same-character difficulty matches, and
2 mutator checks. No clipped baseline, modified thresholds or altered test seeds.
Both retained source fingerprint:
`a645c849380b0e3c8ffdcd7b1321fde07e919a62d018d04189325b55d2dfdd7b`.

| Seed offset | Slot wins | Slot bias | Expert placement share | Warnings |
| --- | --- | --- | --- | --- |
| 300000 | 10/5/5/4 | 0.166667 | 0.533742 | none |
| 900000 | 11/3/6/4 | 0.208333 | 0.468750 | expert bots no better than easy |

Reports: `/tmp/kras-nearest-rival-balance-report/report.json` and
`/tmp/kras-nearest-rival-independent-report/report.json`.
Logs: `/tmp/kras-nearest-rival-balance.log` and
`/tmp/kras-nearest-rival-independent.log`; both passed strict log guards.

Previous same-offset macOS source without this AI change retained slot wins
13/3/2/6 and slot bias 0.291667. Two small samples with this patch remove that
particular warning but do not establish statistical balance or Expert superiority.
The independent difficulty warning remains unresolved. The current Linux campaign
37526080082 is based on older d1a5a31 source and cannot qualify this new branch.

## Release Status

No main merge, Railway deployment, distribution archive, upload or Apple review
submission. Full current-source regression and network-peer qualification,
independent larger balance evidence and physical-device performance remain gates.
