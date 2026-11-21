# Tank qualification after storage recovery

Status: LOCAL_SAMPLE_COMPLETED. Stage 0 remains QA_PENDING / MERGE_PENDING.
This does not qualify every game, tank arena, device, production or release.

## Source And Execution

Source commit before the run: `74283c051d16f6c0572ca5e541f1aa0a36948ace`,
branch `feature/kras-online-random-rotation`. The checkout was clean.
Checkout and isolated runtime gameplay fingerprints matched before launch:
`84d7462fb2b6e91e0837709189107f7abf72933e6905a6dbb51148839fdc9fcc`.
Both report source observations match this fingerprint. No gameplay, AI,
rules, thresholds or source were changed during the campaign.

The corrected persistence log guard SHA256 matched in both directories:
`88918ff13eadf2d53923ff9fc085ee05282183646009847b493acc6b17a59d40`.
This hash is separate because gameplay fingerprints exclude shell/test files.

Godot 4.7.1, headless fixed 60 FPS, `tests/balance_pair_sim.tscn`,
`--only=tank_arena --runs=112 --seed-offset=96000000`, natural duration,
new isolated save and output directories. Process exit 0 in 400.2 seconds.
112 baseline matches, 56 completed difficulty comparisons and two successful
mutator smoke matches: 170 actual match instances. Both engine and stdout logs
passed the corrected runtime guard without unexpected persistence failures.

## Report And Persistence Checks

- Actual baseline seeds and rosters exactly match the rejected prior campaign.
- Every character appeared 56 times, 14 in each seat; every pair met 24 times.
- Expert point share: 0.535714285714286.
- Average simulated duration: 16.3671130952387 seconds.
- Slot bias: 0.0597345132743363; character bias: 0.043141592920354.
- One tied baseline match, zero all-zero-score matches, no aggregate flags.
- Wins total 113 across 112 matches because the tie has shared winners.
- `profile.json`, `profile.json.bak`, and `settings.json` have valid envelope
  MD5 checksums, parseable payloads and schema 2. Secret values were not printed
  or copied into documentation/evidence. These files belong only to test saves.

The initial external report audit referenced a nonexistent `completed_runs`
field and failed. After inspecting the actual schema, the corrected audit used
`runs`, verified completed difficulty samples and all exposure/checksum facts
above. This was an audit-script issue, not an engine/gameplay failure.

## Limits And Next Work

The earlier campaign remains INVALID_SAVE_FAILURE and is not retroactively
accepted. This rerun overlaps its seeds; the two are not independent cohorts
and must not be pooled. Existing earlier weak-difficulty warnings remain in
their original reports; this one sample does not establish universal balance.
Only tank_foundry was used; tank_oasis, tank_frost and variants still need
current, natural-duration qualification and visual/device QA.

Slow cases recurred, so storage failure is not proven to explain all wall-time
variation. No iPhone FPS/thermal/battery claims follow from headless fixed FPS.
Available storage increased from 6.8 GiB before launch to 7.3 GiB afterward;
no files were deleted by this agent. Full archive storage still needs checking
before a current-source Xcode 27 build.

No main merge/push, Railway mutation, signed archive, Apple upload or review
submission. Production backup/restore approval, all-game acceptance and actual
device/release evidence remain separate open gates. No READY/DONE promotion.

## Evidence

Preserved outside Git: `../qualification-tank-recovery-2026-10-12/` contains
report JSON/HTML, both runtime logs and progress file.
Report SHA256: `15716531873d03793b9c1add367d150ee5aff9955ff18f08d6a1c680dc5cdfa2`.
Both logs SHA256: `32dc29e1d474bbdc8801e8722c65f32455ec32e51b39bbfbc91738f2170932d2`.
Original runtime saves: `/tmp/kras-tank-pair-recovery-2026-10-12-save`.
