# Team roster and difficulty investigation

Parent: `a4da85105167ac51dd4277ed63741df2d20bd779`.
Branch: `feature/kras-online-random-rotation`. Engine: Godot 4.7.1.
No gameplay, character, input, physics, scoring or difficulty-profile source
changed in this pass (`git diff HEAD -- src data scenes project.godot` was empty).

## Independent natural-round evidence

Each sample completed 120 baseline matches, 60 mirrored difficulty matches and
two stress variants. These are 546 actual matches across the three samples,
not 1,000 actual matches. All start/end source fingerprints matched per sample.

| Sample | Seed offset | Individual co-first | Team draws | Expert placement share | Flags |
| --- | --- | --- | --- | --- | --- |
| Duo, original adjacent roster | 5800000 | 31/120 | 2/120 | 56.64% | character advantage |
| Duo, diagnostic seeded partitions | 5800000 | 22/120 | 4/120 | 56.64% | none |
| Tank, original adjacent roster | 5900000 | 2/120 | not applicable | 55.91% | none |

The smaller older campaign's weak-Tank-Expert warning did not reproduce in this
larger sample. The Duo character warning is retained, not marked fixed. An
independent Node check recomputed every team's winners/draw from its recorded
shared totals: all 120 samples in each Duo report matched. A partner co-first
result is not automatically a draw between opposing teams.

Original fingerprint (Duo and Tank):
`12534d79685ad156d361ef5141107aa54670d5744e8bd4e163cde0cb3dbb8b7a`.
Diagnostic fingerprint:
`3a16b55a32738308c520239edd6f907c30c77a7de6dbf6060fecb3b0098981b2`.
Changing roster composition changes the experiment; these are not a paired
before/after gameplay-fix comparison, even though the world seeds are retained.

## Explicit diagnostic mode

`tools/balance_sim.gd --balanced-rosters` partitions a locally seeded shuffle of
the registered roster into quartets, rotates each quartet through all four
seats, and reshuffles for the next batch. A complete batch gives every character
equal appearances in each seat. The current eight-character roster is supported;
the parser rejects a pool smaller than four or not divisible by four. A partial
batch alone is not a fully seat-balanced sample. Use whole batches (120 and
1,000 are multiples of eight).

Default commands retain the original adjacent-rotation policy. The report now
records `roster_policy` and the actual `baseline_rosters` for inspection. No
shared/game RNG is consumed by roster selection. Difficulty comparisons remain
the same mirrored, same-character fixtures; acceptance thresholds are unchanged.

Unit tests inspect 1,000 generated configurations, not simulated matches: each
character has 125 appearances per seat, no duplicate character per match, all
seven possible partners, deterministic reproduction and independent seed
variation. A separate Node check of the 120 actually simulated diagnostic
rosters found 15 appearances per seat and all seven partners for each character.

Ordinary campaign aggregation rejects the experimental policy (and malformed
policy values), so its empty flags cannot replace the original campaign warning
or silently become release evidence. Older ordinary reports remain compatible.

## Validation and retained failures

- Roster regression red: 587 passed, one failed; final focused suite: 7,625 passed.
- Aggregation regression red: four failed; green: 83 passed, zero skipped.
- Compile: all 442 scripts compile; runtime log guard passed.
- Full Godot regression: 403,817 assertions passed in 249.2 seconds, engine exit
  zero and positive completed-summary log guard passed.
- Initial ordinary server run failed one local socket test with `listen EPERM`.
  The system-permission retry passed 255 tests with six capture tests skipped.
- Final server run supplied the six actual Godot world captures from the current
  full run: 261 passed, zero failed/skipped. No production data was used.
- Godot logs retain macOS system-certificate-query startup errors under sandbox.
  GDScript/completion guards passed; this is not production TLS/auth verification.

Raw JSON reports, red/green/full/compile logs and both failed/retried server logs:
`../qualification-team-roster-2026-10-09/`. No thresholds were weakened, no old
warnings deleted, no character stats tuned to the observed sample.

## Remaining gates

More independent balanced match samples and per-character gameplay analysis are
needed before deciding whether to change Duo's character physics. Other flagged
games, all-map/device QA, sustained physical-phone performance/energy, production
multiplayer and account-backup/migration approval remain open. Existing remote
campaigns run on older commits and do not certify this modified tool. No main
merge, Railway deployment, native archive, upload or App Review submission occurred.
