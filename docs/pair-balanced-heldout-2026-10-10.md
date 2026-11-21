# Independent pair-balanced Duel sample - 2026-10-10

## Identity and protocol

Checkout: `kras-qualified-current`, branch
`feature/kras-online-random-rotation`, parent
`c70ad93fd8462655b741b33899f0805204e4cf3b`, initially clean.
This phase changes documentation only. It does not modify gameplay, test
fixtures, AI, character stats, canonical sampling or acceptance thresholds.

Godot `4.7.1-stable (official)`, headless, fixed physics FPS 60; imported
runtime `/tmp/kras-tank-pursuit-check`, isolated test storage. The seed offset
92000000 and 112 runs were recorded before execution. The source and all five
diagnostic fixture hashes were checked before/after and against the checkout.

Gameplay fingerprint remained:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
The gameplay fingerprint does not cover the entire asset/native/archive tree;
fixture hashes are separately attested. No files were edited during the run.

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-pair-heldout-92000000.engine \
  tests/balance_pair_sim.tscn -- --runs=112 --only=duel_pit \
  --seed-offset=92000000 \
  --out-dir=/tmp/kras-duel-pair-heldout-92000000-report \
  --test-data-dir=/tmp/kras-duel-pair-heldout-92000000-save
```

## Verified results

- 112/112 natural-duration baseline matches completed.
- 56/56 matched, mirrored difficulty comparisons completed; all raw comparison
  entries explicitly report completion.
- Both mutator and chaos smoke instances completed without flags.
- Total: 170 instances; terminal process exit 0, elapsed 971.1 seconds.
- Stdout and engine logs both pass the unchanged strict runtime guard.
- Mean simulated round duration: 65.0294643 seconds.
- Expert point share: 0.6593592.
- Character bias: 0.1071429; seat bias: 0.0535714.
- Wins: Barq 12, Fanoos 18, Ghaim 8, Mowja 10, Nabta 15, Ramla 10,
  Sakhra 26, Turs 13. Seat wins: 33, 27, 34, 18.
- Ties: zero; zero-score baselines: zero.
- Report warning: `character advantage`.

Exit 0 confirms campaign completion, not absence of balance warnings. The
warning remains a quality issue, not an engine parse/crash failure.

## Independent roster audit

Each actual character appears 56 times and 14 times in each seat; every pair
co-appears 24 times. Each 56-match cycle has 14 distinct quartets, each played
four times. The 112 baseline seeds are unique and disjoint from the prior
88000000 diagnostic. Co-appearance fairness alone does not establish fairness
of teammate roles in team modes; these results concern Duel free-for-all.

The previous equal-pair sample had Sakhra 23/112 and no report flag. This
independent equal-pair sample has Sakhra 26/112 and a flag. Consequently,
unequal opponent-pair exposure is not a sufficient explanation of the
earlier warning. This does not identify a single mechanical cause, prove that
every character is imbalanced, or justify changing shared stats across games.

The four-report review index retains both current warning-bearing samples
(84000000 and 92000000), plus the flag-free samples. It still reports
`requiresBalanceReview=true`, `requiresDeviceReview=true`, `releaseReady=false`.
No report is discarded because it disagrees with a previous result.

## Next corrective investigation

Use controlled contact cases to isolate outgoing power, incoming resistance,
ram mass ratio, damage accumulation and approach speed. Compare identical
positions/inputs with the characters swapped, then inspect the resulting
impulses and falls. Any correction must have a stated gameplay contract and
regression coverage before a new independent natural-duration sample; do not
retune thresholds or select only favorable seeds.

The existing effective-character tests enforce individual movement/combat
property budgets. They do not prove equal combined collision outcomes or win
rates. No change to collision mechanics is claimed in this phase.

## Evidence and remaining gates

Raw evidence: `../qualification-pair-heldout-2026-10-10/` contains report JSON /
HTML, stdout, engine log, progress log, source-before/after, roster audit and
four-report review index. Copied raw files were compared byte-for-byte.

The previous full suite (410,156 assertions) and compile check (455 scripts)
remain evidence for the unchanged code, not fresh runs performed in this phase.
This sample does not qualify all 39 games, real local multiplayer users,
physical controllers, iPhone FPS/thermal/battery behavior or production Online.

Stage 0 remains QA_PENDING / MERGE_PENDING. No main merge/push, Railway
migration/deploy, new Archive, App Store upload or App Review submission was
performed. Main promotion still requires the unresolved production backup /
restore approval; quality and device gates also remain open.
