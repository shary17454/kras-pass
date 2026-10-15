# Tank damage attribution - 2026-10-15

Status: diagnostic infrastructure, not an accepted AI behavior correction.
Stage 0 remains QA_PENDING / MERGE_PENDING.

## Change and source

Base checkout: `c4f9fa79a1d247a76ca6de4e0e25f5619774b186` on
`feature/kras-online-random-rotation`, plus the three files below.
TankController now emits `armor_damaged(shooter, victim, damage, armor_left)`
after applying armor damage and updating the shooter's damage detail, before
elimination. It does not change damage, ammo, scoring, movement, AI decisions,
random draws, perception or network payloads. No production logging is added.

The existing test-only balance trace subscribes to newly added tank controllers
during each match, records the applied damage plus both bodies' positions and
velocities, then disconnects. Weak references avoid retaining old controllers.
Match setup clears the ledger and old subscriptions. Trace data is written only
to the explicitly isolated synthetic test directory, not player saves or a server.

Frozen gameplay fingerprint before and after the campaigns:
`eaf22be8a2e1fc92eec956478b1156c864d7c6afc1be68493036ecec8a4bd65e`.
This fingerprint excludes tests; separately checked source/runtime file hashes:

| File | SHA-256 |
| --- | --- |
| src/minigames/tank_arena.gd | 0b6ef8f2dd7c6861d561e48a2e460a80ae844f14733e55d4a00cc1c8dce0f952 |
| tests/balance_tank_trace.gd | ffec40d6027761e0f3b15ea00e1c07df75bef81e0e002e1e004d4012e8c6436f |
| tests/suites/test_balance_tank_trace.gd | 42a790be8560ba0ca16b3f7fd699f19ae0f41983c078346c1c29f4304a8bd477 |

## Focused qualification

The damage/elimination suite passed 31 assertions including the runner assertion.
It exercises an actual tank controller: one hit, overkill limited to remaining
armor, lethal damage, ignored dead/self hits, idempotent observation, disconnected
old controllers, copied coordinates, unchanged gameplay RNG and encoded input
when recording. The strict test log guard passed. All 466 scripts compiled and
the strict compile log guard passed.

The full Godot suite then passed 427688 assertions in 227.6 seconds, exit 0,
and the strict test-mode log guard passed. The four ERROR lines were traced to
the intentional failed-save test and three router-recovery failures, not ignored
runtime errors. The full log SHA-256 is
`672268e6caada8b5e196cf7c829bfe1b1c79ff48faf432ae3b801397358a31a4`.
No source/test edits overlapped qualification. This is not a new real-network,
server dependency or native device test campaign.

## Natural campaigns

Godot 4.7.1, isolated HOME/save roots, `--headless --fixed-fps 60`:

```sh
godot --headless --fixed-fps 60 --path RUNTIME tests/balance_tank_trace.tscn -- --only=tank_arena --runs=112 --seed-offset=99000000 --out-dir=REPORT --test-data-dir=SAVE
godot --headless --fixed-fps 60 --path RUNTIME tests/balance_tank_trace.tscn -- --only=tank_arena --arena=tank_oasis --runs=112 --seed-offset=99000000 --out-dir=REPORT --test-data-dir=SAVE
```

The first command uses the default foundry. It is not a matched comparison with
the prior oasis sample; the second explicitly selects oasis. Each completed 170
instances (112 baseline, 56 difficulty, two mutator/chaos), exit 0 and strict
runtime log guard passed. No code edits overlapped either campaign.

| Map | Recorded hits | Expert point share | Seat wins | Flags |
| --- | --- | --- | --- | --- |
| Foundry | 2561 | 0.5204991087 | 37 / 29 / 18 / 28 | none in this sample |
| Oasis | 2534 | 0.4125 | 41 / 20 / 28 / 23 | spawn slot; Expert |

Programmatic checks summed each shooter's applied hit damage and matched every
result damage detail in all 340 instances. This validates ledger completeness for
these samples, not all projectiles, devices or future modes.

Oasis rosters, seeds and arenas match the prior stationary diagnostic. Excluding
the new hit field, 167/170 complete rows match exactly. Zero-based row 128 differs only in
elimination snapshots; rows 49 and 164 also differ in details, scores and places.
Do not claim bit-identical observer neutrality or dismiss these differences as
proven noise. No behavior change is intended, but full deterministic equivalence
with the older run has not been established.

## Attribution, not a balance fix

Only the 56 oasis difficulty rows are used below; this is free-for-all, not teams.
Near-stationary means planar speed below 0.5 at the hit callback.

| Shooter -> victim | Hits | Applied damage | Near-stationary victim hits | Lethal hits |
| --- | --- | --- | --- | --- |
| Expert -> Expert | 330 | 7434 | 263 | 56 |
| Expert -> Easy | 179 | 4070 | 21 | 40 |
| Easy -> Expert | 116 | 2773 | 92 | 35 |
| Easy -> Easy | 228 | 5116 | 27 | 34 |

Expert was first eliminated in 50/56 comparisons. In 46 of those 50, another
Expert supplied the lethal hit; Easy supplied four. These observations make
engagement persistence and stationary exposure a concrete next hypothesis.
They do not prove causation or justify changing difficulty thresholds, hiding
failed samples, granting extra stats or leaking unseen opponent information.
Any mobility/disengagement candidate still needs matched and independent tests.

## Evidence and release limits

Sibling directory `qualification-tank-hit-ledger-2026-10-15/` preserves synthetic
logs, reports and traces, not private saves. Report/trace SHA-256:

- Foundry report: `c7af24ea8835b5930cf484cf5885781f926f13091edb86afb10df1c71bf9c35d`
- Foundry trace: `2f4a0cc21adc03e551721341f75f14292a04995721e73bee9f8b3b7da00063d6`
- Oasis report: `d4e42138f752ea94a863e6fc1a8222d47e41d52589c6f8021ef487085c0db6fa`
- Oasis trace: `e64259b95382d4b91b22eded58f8155ec0b0839261c632827986e610ea4a2950`

No physical iPhone/iPad performance, battery, thermal or human playability claim
is made. No merge, push, Railway mutation, fresh iOS archive, upload or Apple
review submission occurred. Existing exported builds are not proof of this source.
