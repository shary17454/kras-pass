# Platform Shortest Route Qualification

Status: **NOT APPROVED FOR RELEASE**. Keep this candidate on its own branch;
do not merge it or use its source in an App Store archive yet.

## Defect And Candidate

Runtime candidate: `67a2eaa3ab3c5ecd54b64a120cefa3a6a2c7888c`.
Parent: `2ac2079752b26ef288685a92e54190cc03bb4eb0`.

The platform brain stored only one first step for each reachable destination.
Two equally short visible cardinal routes to the same solid tile therefore
lost one route according to BFS direction order. Random selection among
destinations could not recover the discarded route.

The regression fixture has two warning-tile corridors to one solid tile.
Four rotations, four seats, and 64 seeded choices per case expose the defect:
the parent chooses one corridor exclusively in all 16 cases. The candidate
retains all shortest first steps, scores their visible safety, and gives each
equally scored first step one vote. Longer paths remain excluded. Reaction,
speed, perception, warning penalties, and balance thresholds are unchanged.

Focused suite: parent 2103 passing assertions / 16 failures; candidate 2119
passing assertions. Compile check: 423 scripts. This proves the route-choice
defect and its focused correction, **not** its effect on overall win fairness.

## Natural Match Comparison

Raw reports and logs: `qa/platform-shortest-route-ties-2026-10-08/`.
Godot 4.7.1 official, fixed physics 60 Hz, unshortened 90-second authored
round window. All matches completed; all paired difficulty samples completed;
both mutator smoke matches completed for each report. Parent/candidate use
identical baseline seeds, characters, seat pairing, and isolated saves.

| Source / Sample | Offset | Baseline / Paired / Smoke | Seat Wins | Expert Edge | Flags |
| --- | ---: | --- | --- | ---: | --- |
| Parent baseline | 1200000 | 24 / 16 / 2 | 8,4,12,0 | 0.56875 | Spawn advantage |
| Candidate baseline | 1200000 | 24 / 16 / 2 | 11,1,5,7 | 0.58125 | None |
| Parent held-out | 1500000 | 24 / 16 / 2 | 6,9,5,4 | 0.50625 | Expert no better than Easy |
| Candidate held-out | 1500000 | 24 / 16 / 2 | 6,2,10,6 | 0.56250 | None |
| Parent expanded | 1200000 | 96 / 48 / 2 | 27,23,29,17 | 0.57708 | None |
| Candidate expanded | 1200000 | 96 / 48 / 2 | 37,15,19,25 | 0.56875 | Spawn advantage |

The candidate's larger sample contradicts an unconditional balance-success
claim. The parent's larger sample also contradicts treating its small-sample
warning as proof of a structural spawn advantage. Do not hide either result,
change thresholds, or claim this route defect caused the original warning.
Further matched expanded held-out validation and investigation are needed.

Parent runtime fingerprint:
`373ff382576009d42c54395613580fdf7acb0b017fa41c2afeead79e9ac9dd7e`.
Candidate runtime fingerprint:
`523906225b6ea660b7726e763b468fe4528b4d604e18bf9d28abe10926e338e3`.
Each report has identical start/end source fingerprints. Parent comparison
checkout `f3b3c9c` has the same runtime fingerprint as the parent above.
The first baseline invocation ignored `--out=` and used the default output
directory; its actual report was recovered there. Subsequent runs use
`--out-dir`. `sample_mode=natural` is verified from every report.

## Performance And Remaining Gates

The retained external planner helper runs 2400 actual tile choices on 113
tiles, discarding one warm-up batch. Parent and repeated candidate timing
bands overlap. The first candidate timing run overlapped compilation; it is
not an isolated comparison. Earlier helper-loading failures were terminated
and corrected with explicit script loading, not counted as successful runs.
These measurements do not establish device FPS, thermal, memory, or battery
acceptance. The helper is stored as `.gd.txt`, outside runtime hash inputs.

Current-source `sh tools/check_party.sh` exited zero: 423-script compile check,
523-resource inventory (22 autoloads, 27 routes, eight characters, zero issues),
391987 test assertions, race regression, six boss checks, and 39 stability
matches with zero failures. The main test runner took 324.5 seconds. All
simulation logs passed the existing runtime log guard. The runtime fingerprint
was rechecked after testing and remains the candidate value above.

The local run also emits a macOS `get_system_ca_certificates` error. The
runtime log guard does not classify that engine/environment diagnostic as a
GDScript failure; do not call the log completely error-free. The stability
test intentionally triggers a memory warning to test cache draining. Neither
that test nor successful cleanup proves long-session device memory behavior.

Fresh server tests use all six actual Godot world captures from this full
gate. The first npm invocation used the repository root (no test script) and
failed before running tests; the corrected invocation runs in `server/`.
Corrected server run: Node 24.18.0, 229 tests passed, zero failures or skips;
exit zero. Completion is recorded separately in the retained log.

Previous native-build evidence uses the parent runtime and cannot qualify
this changed runtime. No current signed archive, upload, processing, review
submission, main merge, or Railway promotion occurred.
