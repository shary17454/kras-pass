# Current-source Base Siege qualification

Tested clean checkout: `/tmp/kras-match-teardown-quiescence`.
Branch: `fix/kras-match-teardown-quiescence`, PR 181.
Tested commit: `5cb849ab1aecb7f370550fc511eb530164faa6b5`.
Godot: 4.7.1 official, headless, fixed simulation FPS 60, isolated saves.
No runtime or balance thresholds were changed for these runs.

## Reproduction and second seed set

The older all-39 campaign at c5fa1f9 reported Base Siege Expert share
0.50920245398773, below the existing 0.52 review threshold. That warning is
retained; it is not evidence for the changed current source.

For each OFFSET in 1200000 and 1500000:

```sh
/opt/homebrew/bin/godot --headless --fixed-fps 60 \
  --path /tmp/kras-match-teardown-quiescence tools/balance_sim.tscn \
  --log-file /tmp/kras-current-siege-natural-OFFSET.log -- \
  --only=base_siege --runs=24 --seed-offset=OFFSET \
  --test-data-dir=/tmp/kras-current-siege-natural-OFFSET-save \
  --out-dir=/tmp/kras-current-siege-natural-OFFSET-report
```

Both processes exited 0. Both stdout logs passed `tools/check_godot_log.sh`.
The authored baseline/difficulty round window was 105 seconds, not a clipped
14-second balance sample. The two mutator/chaos checks per seed set use the
existing short stress fixture; they are completion checks, not balance evidence.

| Seed offset | Baseline | Paired difficulty | Stress | Expert share | Character bias | Slot bias | Tie rate | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1200000 | 24 | 16 | 2 | 0.521212121212121 | 0.125 | 0.166666666666667 | 0 | None |
| 1500000 | 24 | 16 | 2 | 0.576687116564417 | 0.075 | 0.11 | 0.0416666666666667 | None |

Total: 84 completed runs, comprising 48 baseline games, 32 paired comparisons
and four short stress checks. Every difficulty pair uses the same character and
seed, with Expert slots swapped [0,1] then [2,3], covering all eight characters.
Baseline seeds and both stress seeds matched the expected offset policy.

## Evidence integrity

Raw reports are committed alongside this document:

- `siege-current-natural-1200000.json`, SHA256
  `12f5749328af54c5da2959e5912e4f0d9a13ecd901e9f70fcaaffba6736fdc0e`.
- `siege-current-natural-1500000.json`, SHA256
  `a7fbcf41942e6362d2c6c6b61f711cdde28c94c991c23817f246058d540981f8`.

Both simulation_source_start and simulation_source_end matched a fresh
independent calculation over the current simulation roots/extensions and
project.godot: `befd16c8f87806665ff89a9de87a83a4ecc7455438ce29c74e5fc7bb4223087e`.
The checkout remained clean throughout simulation; only these evidence documents
were added afterward. No GitHub campaign provenance was invented for local runs.

## Interpretation and remaining gates

The old difficulty warning did not reproduce in these two current-source samples.
The first Expert share is only just above the unchanged review threshold, so
this is not proof of robust balance across arbitrary seeds or human play. Do not
claim all 39 games READY, causal attribution to any one prior fix, sustained FPS,
physical-phone heat/battery qualification, or release acceptance from this sample.

Fresh GitHub inspection found old campaign 37577604329 terminal SUCCESS with all
41 jobs completed; its four balance review warnings remain in the raw all-39
summary. Parent-source campaign 37616445234 was still queued overall with four
completed jobs, one in progress and 35 queued, no failures, source
96c53f359cbb48663a9a99d3fec5ecf6e16d16af. It was not cancelled or duplicated.

Current teardown fixes are not in the preserved local candidate 111 archive.
Complete current-gameplay/device/production gates, freeze the approved release
source, and make a new LOCAL Xcode 27 Distribution archive before upload.
No main merge, production operation, phone install, archive, upload, processing
or review submission occurred in this qualification step.
