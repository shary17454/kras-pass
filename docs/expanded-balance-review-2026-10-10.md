# Current-source expanded balance review

Runtime source: `c46a7f105e627ac6406ea6beebb2784916ba7fdf`, branch
`feature/kras-online-random-rotation`. Checkout and both completed local reports
share fingerprint `234b08ecdd5a63a4a6231dde70166ee9dd4f526e268208d731c7b5b8da5da3c4`.
Godot: `4.7.1-stable (official)`. Both processes exited zero and passed
`tools/check_godot_log.sh`. No runtime, character or acceptance-policy edits
were made during this review.

## Expanded natural samples

Each game used 96 completed baseline rounds, 48 completed paired difficulty
rounds and two successful mutator/chaos rounds: 146 matches per game.
Seed offset: 0. Roster policy: `seeded_partition_seat_rotation`.
Start/end source fingerprints match. Total completed local matches: 292.

| Game | Character bias | Slot bias | Expert share | Remaining flag |
| --- | --- | --- | --- | --- |
| blast_ball | 0.0208333333 | 0.0104166667 | 0.5041666667 | expert bots no better than easy |
| tank_arena | 0.0688775510 | 0.2193877551 | 0.5958762887 | spawn slot advantage |

Tank baseline wins by slot: `[46, 11, 29, 12]`; this is a review signal, not a
proven collision/AI root cause. Blast baseline wins: `[25, 22, 24, 25]`.
Tank qualification took 589.7 wall seconds. A one-second process sample was
retained; unsymbolicated stacks do not establish a runtime bottleneck or leak.

## Preserved campaign and CI evidence

Campaign `37997079439` completed successfully on the older commit
`9b88f560c13e54655399aa54615091ea9e397cf8`: 39 games, 1638 matches.
Downloaded artifacts were revalidated for source consistency and paired
difficulty. Its flags remain visible: Blast expert difficulty, Tank spawn
advantage and armed-race character advantage. `releaseReady=false` and
`balanceReviewComplete=false`.

The old campaign used adjacent rotating rosters, not the expanded balanced
partition policy. Do not interpret differences between these samples as a
before/after intervention or add overlapping seeds as independent evidence.
Armed-race expanded current-source qualification remains outstanding.

Current-source Core run `38015873710` completed with conclusion `success` on
`c46a7f105e627ac6406ea6beebb2784916ba7fdf`. Detailed artifacts have not yet
been audited in this batch; no assertion count is inferred from older runs.

## Commands and retained evidence

Run separately, never concurrently:

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check tools/balance_sim.tscn -- --only=blast_ball --runs=96 --balanced-rosters --seed-offset=0 --out-dir=/tmp/kras-blast-current-expanded-report --test-data-dir=/tmp/kras-blast-current-expanded-save
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check tools/balance_sim.tscn -- --only=tank_arena --runs=96 --balanced-rosters --seed-offset=0 --out-dir=/tmp/kras-tank-current-expanded-report --test-data-dir=/tmp/kras-tank-current-expanded-save
```

Reports, stdout and the current-source sample index are retained at
`../qualification-expanded-balance-2026-10-10/`. The older campaign artifacts
remain at `/tmp/kras-balance-9b88-37997079439` with verified summary
`/tmp/kras-balance-9b88-verified-summary.json`.

This is diagnostic qualification, not a balance fix, all-game readiness,
stage completion, device performance approval or release approval. Main
promotion, production DB qualification, Railway deployment, native release
archive, Apple upload and review submission remain separate open gates.
