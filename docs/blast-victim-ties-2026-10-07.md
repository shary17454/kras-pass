# Blast Ball Victim Tie Selection

Base: 8a393da147c90eb0738440ffa25fa23dbfe580b0.

## Confirmed Fix

The specialised Blast Ball brain selected the lowest eligible seat when
several visible opponents were equally close to its observed ball position.
This selector does not use the previously corrected shared nearest-rival
helper. It now collects the final nearest candidates and uses its existing
seeded RNG only if that final set has multiple members.

Unique nearest selection, visibility filtering, delayed position perception,
reaction delay, movement, attack strength, scoring and explosion rules remain
unchanged. This is an unbiased tie selection fix, not a claim that Expert
difficulty has been balanced.

## Regression Evidence

- Red: 3959 assertions passed and 3 failed.
- Green: all 3962 AI-visibility assertions passed.
- 900 symmetric choices cover all three equal visible victims without
  deterministic seat preference; 30 choices replay from the same seed.
- A uniquely nearer final candidate wins without consuming RNG even when
  earlier seats had a temporary tie.
- Existing hidden/reappearing-victim checks remain active.
- All 396 scripts compile; runtime log guards and git diff --check pass.
- Logs: /tmp/kras-blast-ties-{red,green,compile}.log.

## Retained Natural Balance Failure

Same independent seed offset900000, natural24 baseline+16 paired difficulty
matches+2 mutated/chaos checks completed before and after this fix.

Before: Expert edge0.48125, warning `expert bots no better than easy`.
Source fingerprint start=end:
60d5d4a006f60a392379c82a5731ab4fbc949f174c434955345c35092c240165.
Report: /tmp/kras-blast-independent-report/report.json.

After: Expert edge0.48125, same warning retained.
Source fingerprint start=end:
49845c37b2be8635e675dfcba28fd2afcfb8abfcaa106f12205d33fa68399025.
Report: /tmp/kras-blast-ties-natural-report/report.json.

Both runtime log guards passed. The real tie bug did not explain or repair
the difficulty failure in these naturally played samples. No seeds or
thresholds were changed to suppress the warning.

Independently, current-parent Gem Grab at offset900000 retained spawn-slot
advantage0.23148148 and Expert edge0.49707602. This confirms that its earlier
height placement fix and a single passing sample do not certify game balance.

## Remaining Gates

Expert strategy and Gem Grab routing/balance remain open. Full post-fix
release gate, physical-device QA, production integration/deployment,
Distribution archive, upload and Apple submission were not performed here.
