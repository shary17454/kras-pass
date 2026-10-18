# Current Colossus Natural Qualification

Tested commit: 3a645abb53882bd101ccbe80e57c0abf3c58373a.
Branch: fix/kras-blast-survival-margin. No runtime change was made during this
test. Godot 4.7.1 official, headless, fixed simulation FPS 60.

Command:
```
godot --headless --fixed-fps 60 --path . tools/balance_sim.tscn \
  --log-file /tmp/kras-current-colossus-natural-1200000.log -- \
  --runs=24 --only=boss_colossus --seed-offset=1200000 \
  --out-dir=/tmp/kras-current-colossus-natural-1200000-report \
  --test-data-dir=/tmp/kras-current-colossus-natural-1200000-save
```

Process exit 0, 222.9 seconds wall time. Runtime log guard exit 0. The existing
macOS system CA-access diagnostic is retained; no script/load/leak failure
matched the guard. Storage was isolated from player saves.

Source fingerprint before and after, identical:
ba25854f89b88fb1b85f1324dfdcf2c5303471d4bb85cc506d614b5e3ca958e5.
Raw result: colossus-current-natural-1200000.json.

## Outcomes

- 24 authored-duration baseline matches completed, average simulation duration
  124.9375 seconds, authored maximum window 150 seconds.
- Boss defeated 22 times, survived twice, zero unknown objective outcomes.
- All 16 mirrored same-seed/same-character Easy/Expert comparisons completed;
  boss defeated in all 16. Expert edge metric 0.6829268.
- Mutated and chaos matches completed naturally, but the boss survived both.
  Successful stability checks are not successful boss objectives.
- Tie rate 0.1666667, spawn-slot bias 0.0948276, character bias 0.0818966,
  no statistical warnings in this sample.
- verifyBossOutcomeEvidence and verifyBossComparisonEvidence accepted the raw
  seeded objective counters and comparison/stress records.

One seed family and scripted Bots do not certify human enjoyment, every
difficulty configuration, physical multiplayer, device frame pacing, Internet
transport or complete character balance. Stress survival remains a review point
when tuning the family/chaos experience, not an erased result.

## Existing Linux Campaign

Read-only inspection of run 37577604329 confirmed 32 completed games, zero job
failures, seven games still queued. Downloaded artifacts validated as 1344
natural matches on OLD commit c5fa1f9813478ed8ab3a6ef26033e93b57b65928.
Aggregate: campaign-37577604329-partial32.json. The old Blast Ball difficulty
and Star Rush character warnings remain. Partial output has releaseReady=false
and cannot qualify the current changed source. No duplicate run was started.

No main merge, Railway deployment, phone installation, archive replacement,
upload, processing or Apple review submission occurred.
