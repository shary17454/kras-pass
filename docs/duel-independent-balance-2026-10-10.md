# Duel Pit independent balance review

## Source and experiment

Tested gameplay commit: `afcfc9cf5fce98c97d732de58b9a3f1c3ba1ed5e`, branch
`feature/kras-online-random-rotation`. Existing uncommitted changes at launch
were documentation only. Godot 4.7.1-stable (official), imported isolated runtime
`/tmp/kras-tank-pursuit-check`, headless fixed simulation rate 60.

Source fingerprint checked against checkout/runtime before the first run and
recorded unchanged at start/end of both reports:
`adbbda6d74c6f6d6fb5f508ec50970e3123381f34a38f28329759d57b75ad1dd`.
This is selected simulation-source evidence, not full assets or a native archive.
No runtime, test, rule, AI, physics or acceptance-threshold edits in this phase.

Two separate sequential campaigns on the default `duel_pit` arena:

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-independent-80000000.engine \
  tools/balance_sim.tscn -- --runs=96 --only=duel_pit --balanced-rosters \
  --seed-offset=80000000 --out-dir=/tmp/kras-duel-independent-80000000-report \
  --test-data-dir=/tmp/kras-duel-independent-80000000-save
```

Second run used seed offset `84000000` and corresponding `heldout-84000000`
paths. No tuning change or selection of favorable seeds occurred between runs.
Each completed 96 natural baseline, 48 matched/mirrored difficulty comparisons,
and two mutator/chaos smoke instances: 146 each, 292 total. Both exit codes 0;
all four stdout/engine logs passed the unchanged runtime guard. Elapsed report
times: 478.9 and 365.8 seconds. These are host simulation times, not phone FPS.

Roster policy is `seeded_partition_seat_rotation`, supplementary rather than
canonical `adjacent_rotation`. Every character participated in 48 baseline
matches in each sample. Both baseline seed sets have 96 distinct values.

## Results

| Metric | Independent 80000000 | Held-out 84000000 |
| --- | ---: | ---: |
| Expert point share | 0.636182902584493 | 0.662698412698413 |
| Character bias | 0.1875 | 0.145833333333333 |
| Seat bias | 0.104166666666667 | 0.03125 |
| Sakhra wins | 30 / 96 | 26 / 96 |
| Sakhra wins / appearances | 30 / 48 | 26 / 48 |
| Mean natural duration | 63.6923611111088 s | 63.9789930555532 s |
| Ties | 0 | 0 |
| Zero-score matches | 0 | 0 |
| Flags | character advantage | character advantage |
| Mutated / chaos smoke | both pass | both pass |

Wins by seat: 19,34,22,21 and 27,25,20,24. Wins by character respectively:

| Character | Independent | Held-out |
| --- | ---: | ---: |
| Barq | 5 | 10 |
| Fanoos | 19 | 10 |
| Ghaim | 9 | 6 |
| Mowja | 6 | 11 |
| Nabta | 9 | 7 |
| Ramla | 10 | 10 |
| Sakhra | 30 | 26 |
| Turs | 8 | 16 |

The canonical 24-match warning was seat bias 0.25 (12,5,1,6 wins). That exact
warning did not recur in either larger independent sample; it is not deleted
or declared false. Character advantage did recur, and is the next investigation
priority. Equal raw stat totals and passing effective-stat-budget tests are not
evidence of equal game-specific win rates.

## Inspection and next acceptance gate

The default arena is a multi-tier pit with fixed angular ledges, while fallback
spawn positions form an evenly spaced ring. DuelBrain prefers observed damaged
rivals and uses delayed damage cues; it does not use an unconditional first-slot
tie choice. Fighter._apply_hit combines accumulated damage, attack power and
resistance. These inspected paths suggest controlled combat/geometry experiments;
they do not prove which factor causes the repeated character signal.

Next: isolate geometry versus effective power/resistance on the alternate arena
and matched inputs before a narrowly scoped balance change. Preserve heavy
character identity and all other minigames; do not reduce global stats merely to
make this report green. Re-run representative held-out samples after any change.

Raw JSON/HTML and original logs:
`../qualification-duel-independent-2026-10-10/`. Previous canonical reports and
warnings remain in their original evidence directory and documents.

No READY/DONE promotion, new features, main merge/push, production migration,
Railway deployment, native archive, upload or Apple review submission occurred.
Stage 0 remains QA_PENDING/MERGE_PENDING; later gated stages remain locked.
