# Current-source tank qualification

Status: TESTS_PASSED / BALANCE_NOT_ACCEPTED.
Stage 0 remains QA_PENDING / MERGE_PENDING. No release or READY promotion.

## Source And Recovery

Repository: shary17454/kras-pass, origin HTTPS; branch:
`feature/kras-online-random-rotation`.
The checkout was clean before and after execution. Source commit:
`ab04d37941b4061000168a69cf68158020969e38`.

The prior temporary runtime was no longer available. A fresh Git archive of
this exact commit was successfully exported and extracted into
`/tmp/kras-ab04d37-qualified-2026-10-15`.
Archive SHA256:
`106feb0533d1d72d9c79dd8cd5a925c2e290b1feb44456fb0e3d93b145990abf`.
The evidence filenames use 2026-10-15, but execution took place on
2026-10-14 UTC and Riyadh time. They were not renamed during execution.

Gameplay fingerprint of the extracted commit:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
Both campaigns recorded this fingerprint at start and end. A final external
fingerprint also matched. No gameplay, AI, rules or thresholds changed.
The live checkout fingerprint reader timed out after 90 seconds (exit 142);
this is evidence for the archived commit, not a completed live-tree capture.
Local Data storage had approximately 63 GiB free before execution. This does
not prove permanent resolution of the cloud-backed filesystem issue.

## Import And Tests

Godot reports 4.7.1-stable. The first sandbox import returned exit 0 but logged
system CA and editor-settings write errors; it is not an accepted clean import.
After that process ended, a local import with a separate temporary HOME passed
with exit 0 and the strict import guard. No certificates were changed or imported.

- Log-guard unit tests: seven passed, no failures or skips.
- Compile check: 458 scripts, positive completed summary, exit 0; strict guard passed.
- Spawn-clearance suite: 273 assertions in 9.9 seconds, exit 0; strict guard passed.
- Full suite: 419583 assertions in 258.7 seconds, exit 0; strict test guard passed.

The suites use isolated save directories. Expected failure-injection warnings
in unit tests are not runtime campaign acceptance. This headless evidence does
not establish physical controller, iPhone rendering, FPS, battery or thermal QA.

## Natural Matched Map Campaigns

Both maps used `tests/balance_pair_sim.tscn`, fixed FPS 60, natural durations,
112 baseline matches, seed offset 96000000, 56 completed difficulty comparisons
and two successful mutator/chaos smoke matches: 170 instances per map.
Both processes exited 0 and both engine logs passed the runtime guard.

| Metric | tank_oasis | tank_frost |
| --- | --- | --- |
| Wall time | 143.0 s | 115.7 s |
| Average simulated duration | 16.379464 s | 10.784970 s |
| Seat wins P1/P2/P3/P4 | 40/14/37/21 | 35/18/27/32 |
| Slot bias | 0.1071428571 | 0.0625 |
| Character bias | about 0.04 | 0.0803571429 |
| Expert point share | 0.4267857143 | 0.4625 |
| Ties / all-zero-score rounds | 0 / 0 | 0 / 0 |
| Flags | spawn slot advantage; expert bots no better than easy | expert bots no better than easy |

External assertions verified identical baseline seeds, rosters and difficulty
seat swaps across the two maps. Every character appeared 56 times, 14 in each
seat; every one of the 28 character pairs met 24 times. These samples match the
previous campaign seed cohort; do not count reruns as independent evidence.

For each campaign, profile.json, profile.json.bak and settings.json have valid
MD5 envelope checksums and schema 2. No secret values were printed or preserved
in the evidence directory. Both balance warnings remain unresolved.

## Diagnostic Direction

In Oasis difficulty samples, Expert delivered 12318 damage and 96 knockouts
versus Easy's 6621 damage and 71 knockouts, but total scores were 25048 versus
34513. The game's compute_scores uses survival ordering and surviving armor,
not damage or knockout totals. More successful attacks do not prove better
survival. This observation motivates elimination-order, exposure, targeting and
route diagnostics; it does not establish a causal AI bug or justify changing
scoring, stat budgets or acceptance thresholds.

## Preserved Evidence

`../qualification-ab04d37-2026-10-14/` contains import, compile, spawn, full-suite
and campaign engine logs plus both report JSON/HTML directories.
Temporary save data is not copied into this directory.

- Oasis report SHA256: `a1de51f7e55c918ac315d66f5fbd3adcb91210de7a57c359383efecdd26c717d`.
- Frost report SHA256: `c686cae23ecef90b9a681f1bf398dfc28642ab2ae285b0526925039a060f4a33`.
- Full engine log SHA256: `469a7cebd73ab10ee0a14ba719aeefb88f389bff86b60fd34aa36b6c85251af1`.

No merge/push to main, Railway mutation, signed Xcode archive, Apple upload or
review submission occurred. Production backup/restore authorization and actual
device/release acceptance remain separate gates. Next: causal tank survival and
slot diagnostics, then a narrowly scoped candidate with matched and held-out
campaigns; preserve failed candidates and all original warning evidence.
