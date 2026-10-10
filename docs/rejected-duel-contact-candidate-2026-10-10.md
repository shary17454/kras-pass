# Duel contact candidate rejected after matched comparison - 2026-10-10

## Scope and protocol

Parent: `33c51fb2cf45b39bd0e626fbc5d9d6dfafda7f2a`, initially clean,
branch `feature/kras-online-random-rotation`. Godot `4.7.1-stable (official)`.
All source/fixture verification completed before launching the matched sample.
No source, fixture, data, tool or scene edits occurred during that campaign.

The candidate removed character resistance from the outgoing ram mass ratio
in Duel only. Its controlled assertions passed, but balanced gameplay was
still unproven. This phase tests that hypothesis against actual matches.

```sh
godot --headless --fixed-fps 60 --path /tmp/kras-tank-pursuit-check \
  --log-file /tmp/kras-duel-contact-matched-92000000.engine \
  tests/balance_pair_sim.tscn -- --runs=112 --only=duel_pit \
  --seed-offset=92000000 \
  --out-dir=/tmp/kras-duel-contact-matched-92000000-report \
  --test-data-dir=/tmp/kras-duel-contact-matched-92000000-save
```

The candidate is source `b97e86741b7e6a19a8b3eff113c376036abf342e1a1e6b79bb5e03ed50b23fa3`.
The reference is source `84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
Both source snapshots and checkout/runtime equality were verified afterward.
The 112 baseline seeds and actual rosters match exactly, as do all 56
difficulty seed/character/expert-slot assignments. This is a matched diagnostic,
not new held-out evidence after selecting the rule.

## Actual outcome

- 112/112 natural baseline matches, 56/56 difficulty comparisons and both smoke
  instances completed: 170 instances total, terminal exit 0, elapsed 782.1 s.
- Both stdout and engine logs pass the stricter guard retained from 33c51fb.
- Each character appears 56 times, 14 in each seat; every pair meets 24 times.
- Sakhra wins: 26/112 before, 31/112 after.
- Character bias: 0.1071429 before, 0.1517857 after.
- Candidate wins: Barq 7, Fanoos 9, Ghaim 14, Mowja 11, Nabta 12, Ramla 12,
  Sakhra 31, Turs 16. Seat wins: 32, 22, 30, 28; seat bias 0.0357143.
- Candidate Expert point share: 0.6442953; mean round duration 62.9682 s.
- Ties and zero-score baselines: zero. Mutator and chaos flags: none.
- `character advantage` remains present.

The aggregate increase is not a claim of statistical significance or sole
causality. It does demonstrate that this candidate did not clear the existing
balance warning. A green contract test alone is insufficient acceptance.

## Disposition and restoration

The candidate is `REJECTED_BALANCE_CANDIDATE`. Only our own gameplay additions
from 33c51fb were removed with scoped patches: the optional ram character-mass
field/equation branch and the Duel override. No user changes were reverted,
no shared Git history was rewritten and no gameplay files were replaced with
an unrelated checkout.

The complete gameplay fingerprint returns exactly to source 84d in both the
checkout and runtime. The earlier damage/lives fix remains active. The genuine
qualification-log guard fix, its Node tests and CI configuration remain intact.

The contact test now explicitly checks the established equation in both Duel
and Ring. The withdrawn one-factor rule was our experimental design, not a
required user contract. This regression check does not certify that the current
equation is balanced. The failed candidate's old assertions, measurements and
matched reports remain reproducible at 33c51fb and in the raw evidence.
No balance thresholds or report flags were weakened to obtain a pass.

## Fresh restoration verification

- Controlled equation suite: 9,218 assertions, exit 0, 2.1 s.
- Compile: 456 scripts, completed success summary, exit 0.
- Fresh full suite: 419,373 assertions, exit 0, 343.3 s.
- All six controlled/compile/full stdout and engine logs pass stricter guards.
- Existing iOS guard plus Godot guard tests: 13 pass, zero fail/skip.
- Pre-launch restoration snapshot and post-full hashes agree; checkout/runtime
  files are identical. Tests, shell/JS helpers and native/archive/most assets
  are outside the selected gameplay fingerprint and are attested separately.
- No fresh network campaign or physical-device performance test in this phase.

The five-report review index retains historical candidate outcomes and both
current 84d warning-bearing samples. It still requires balance/device review
and reports `releaseReady=false`; the rejected b97 report is not current-source
qualification. Overlapping before/after seeds are not counted as independent
evidence or pooled to dilute a warning.

## Evidence and next action

Raw evidence: `../qualification-duel-contact-matched-2026-10-10/` contains
matched report/log/progress files, source-before/after, `comparison-audit.json`,
restoration snapshots/logs, guard results and `review-history.json`. Raw copies
were compared byte-for-byte; the audit checks actual rosters and assignments.

Next: collect per-match hit/fall/knockout and decision evidence on the restored
source to isolate AI tactics and unassisted falls before another intervention.
Do not run the planned b97 independent 96000000 acceptance sample: that
candidate has been withdrawn. Do not infer that weight is the sole cause or
blindly change shared character stats.

Stage 0 remains QA_PENDING / MERGE_PENDING. No game is promoted to READY here.
No main push/merge, Railway deploy/migration, Archive, upload or App Review
submission occurred. Production backup/restore approval and device/quality
gates remain unresolved; the full product scope is not completed.
