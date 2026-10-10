# Independent Tank Balance Cohort

Source: `c9777a71673b096feacd2bf3b4dec94245406571`.
Runtime matches `cbe2124812008bd55746e1d0e50c49087ad2ef74`;
the intervening commit only adds documentation.
Branch: `feature/kras-online-random-rotation`, Godot 4.7.1 official.
Runtime fingerprint:
`e4c56526502dda4d61619177508c937cfc0c77369f02c4df9d07114348880ed2`.
The imported runtime and Git checkout fingerprints were matched directly.

## Independent Natural-Round Results

Command (isolated player saves; no round clipping):

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check tools/balance_sim.tscn -- --only=tank_arena --runs=96 --balanced-rosters --seed-offset=16000000 --out-dir=/tmp/kras-cbe-tank-independent-report --test-data-dir=/tmp/kras-cbe-tank-independent-save
```

Exit 0 in 178.8 seconds. Strict Godot log guard passed. Report start/end
fingerprints are identical and match the current checkout. All 96 baseline,
48 matched-seed/character difficulty and two mutator/chaos matches completed.
Structured comparison confirmed no seed overlap with the previous offset-zero
146-match expanded cohort. The cohorts have different runtime fingerprints;
they are not pooled into a single current-source acceptance sample.

| Measurement | Current independent cohort |
| --- | --- |
| Slot wins | 31,24,19,22 |
| Slot bias | 0.0729166667 |
| Character bias | 0.0625 |
| Expert points share | 0.51875 |
| Average round seconds | 15.3887152778 |
| Severity | 1 |
| Flag | expert bots no better than easy |

No spawn or character bias warning appeared in this sample. The difficulty
warning remains unresolved: the earlier offset-zero sample's empty flags do
not override this independent result. A completed simulation and exit zero
are not a balance pass. No acceptance threshold, Bot stats, damage or rule was
changed to suppress this warning. The sample uses the default arena, not all
three tank arenas, and is not device-performance evidence.

## Server And Core Evidence

Current-source local server tests initially passed 270 with six capture tests
skipped. A second invocation supplied the six actual Godot JSON captures from
the complete current regression run: 276 passed, zero failed, zero skipped.
This validates server schemas against current captured state, not production
Railway authentication, database state or native network connectivity.

Prior-source Core run 38018319419 completed successfully. Downloaded manifest
matches source `15279bfa95aaadeeb081a35c88d477bc81cf8e74`, clean tracked files,
run identity and intended head. Its complete regression passed 407372
assertions in 439.3 seconds; stability completed 117 matches with zero
failures. Both logs passed their strict guards. It predates the racer-pad
perception change and cannot attest the current runtime.

After that run became terminal, current-source Core run 38019424372 was
dispatched and confirmed in progress on c9777a7. Its separate concurrency
group leaves balance campaign 38018326003 untouched. No completed outcome is
inferred for either pending campaign.

## Evidence And Remaining Work

Raw report, stdout, source-aware review index, seed-disjointness check and both
local server stdout logs are retained at:
`../qualification-current-tank-independent-2026-10-10/`.
Downloaded prior-source Core artifacts are at
`/tmp/kras-core-152-38018319419/`.

Next tank task: examine difficulty decision quality and rerun paired cohorts
without hidden stat advantages or privileged perception. Current-source full
39-game qualification, native device/controller/energy QA, remaining product
features and production/release gates remain open. No READY classification,
new-stage acceptance, main promotion, Railway deployment, signed archive,
Apple upload or submission is claimed.
