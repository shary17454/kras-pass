# Duel observational contact diagnostic

Status: DIAGNOSTIC_ONLY. Stage 0 remains QA_PENDING / MERGE_PENDING.
No gameplay change, new balance acceptance, deployment or release submission.

The test-only driver extends the existing pair-balanced natural match driver.
It subscribes to hit and respawn events only during each match, disconnects
after cleanup, and writes one JSONL record per completed attempt. It does not
sample RNG, change input, physics, AI, results or acceptance thresholds.
Respawn event counts are not fall counts: eliminated players do not respawn.
The result details remain authoritative for falls and credited knockouts.
Emitted hit strength is knockback magnitude, not measured physical displacement.

## Completed Campaign

- Godot 4.7.1, headless fixed 60 FPS, isolated temporary runtime and save root.
- 56 natural Duel matches, 28 mirrored difficulty comparisons, 2 mutator smoke
  matches: all 86 trace records completed; process exit 0, 188.6 seconds.
- Every baseline seed and roster matches the first 56 entries of the existing
  92000000 held-out campaign. This overlaps that campaign; it is not independent
  held-out evidence and must not be pooled as additional independent matches.
- Source start/end fingerprint:
  `84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
- Gameplay fingerprint excludes tests/assets/native output. Separate trace
  driver SHA256: `6db6002d8405a35e6123b3ae20357305996e44ee55488ac40d12d03c20721585`.
- Strict runtime log guard passed. Compilation passed for 457 scripts before
  adding the separate ledger unit suite. Initial fixture syntax failure was
  corrected before running any matches; it is not a gameplay defect.
- Final compilation passed for 458 scripts. The focused ledger unit suite
  passed 11 assertions; both final logs passed their strict guards. The complete
  test suite and device/network campaigns were not rerun in this phase because
  the changes are confined to test instrumentation, its registration and docs.

## Natural Match Observations

Each character appeared 28 times. Wins: Nabta 7, Ghaim 5, Fanoos 11,
Mowja 6, Sakhra 11, Turs 6, Barq 6, Ramla 4.
Sakhra received 943 hit events with aggregate strength 14418.77 and delivered
957 events with aggregate strength 18897.70. Its 71 falls were the lowest in
this sample. Fanoos also won 11 matches; Turs had more credited knockouts (97)
than Sakhra (93), despite only 6 wins.

These are observations, not a causal attribution or statistical proof.
Movement, damage at impact, pickups, encounter direction and AI exposure can
all affect aggregates. No fresh balance candidate is justified solely by them.
The earlier 112-match character-advantage warning remains unresolved even
though this smaller overlapping sample had no aggregate warning.

## Evidence

- `/tmp/kras-contact-trace-92000000-report/report.json`
- `/tmp/kras-contact-trace-92000000-save/contact-trace.jsonl`
- `/tmp/kras-contact-trace-92000000.engine`
- `/tmp/kras-contact-trace-compile-fixed.engine`
- `/tmp/kras-contact-trace-final-compile.engine`
- `/tmp/kras-contact-trace-unit.engine`

These diagnostics do not qualify production Railway, device performance,
archive signing, App Store upload or review. Main push remains blocked by the
previous production migration/backup approval gate; no bypass is authorized.
