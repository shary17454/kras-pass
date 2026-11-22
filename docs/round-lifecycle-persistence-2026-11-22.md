# Atomic Round Persistence And Replay Pause

Baseline: 9b629317c1785ea5e3caf48dffbdb8caa30e4432.
Branch: fix/round-persistence-ai-20261122.

## Atomic Completion

Previously MatchScene committed match statistics and their receipt before the
tournament callback committed its next checkpoint. Reading the real save file
at that boundary reproduced matches=1, receipt=true, checkpoint=0. A process
interruption could therefore replay a round whose older outcome was already
rewarded and refuse statistics for its replacement result.

The local non-replay completion path now holds an outer SaveSystem batch through
the synchronous owner callback. Existing nested batches and flushes cannot write
an intermediate profile. Match and cup receipts, rewards, achievements, replay
index and the checkpoint share one final profile write. The disk format and
schema are unchanged; online and replay completion do not enter this batch.
Replay files remain separate sidecars, not an atomic multi-file database.

Regression reads the disk before the owner callback, after it, and on duplicate
delivery, for both an intermediate round and a completed cup. It checks a single
save event, restored standings, rewards and receipts. Original routing remains
covered by 1-4 human tournament cases. tournament_flow: 266 assertions passed.

## Replay Lifecycle Pause

Previously only live-input playback checked playback_paused. Timed INTRO,
INSTRUCTIONS, COUNTDOWN, FINISH and NEXT_ROUND phases still advanced, including
round-result delivery. New lifecycle regressions reproduced 56 failures.

The common phase tick now returns while transport pause is active. Explicit
seek re-simulation retains its existing bypass so seeking works while paused.
Tests enter all six phases through the ordinary lifecycle, hold pause longer
than the phase duration, and check timers, ticks, results, events and exact
single-step resumption. replay_transport: 730 assertions passed after the fix.

## Integrated Targeted Qualification

Godot 4.7.1 official a13da4feb, local macOS, isolated saves. All 479 scripts
compiled. Eight suites passed their terminal exit and strict tests log guards:

| Suite | Assertions |
| --- | ---: |
| ai_visibility | 4568 |
| tournament_flow | 266 |
| party_progress | 133 |
| replay | 80 |
| replay_seek | 148 |
| replay_transport | 730 |
| lifecycle | 58 |
| save | 111 |

Total: 6094. Evidence is outside Git in the sibling
qualification-quickplay-20261122/postfix-regressions-r1 directory. Earlier
sandbox certificate diagnostics were retained separately, not counted as clean
qualifications. Save fault injection is checked by the existing tests-mode
log guard, not silently removed from the logs.

The complete suite, representative balance acceptance and physical-device QA
remain separate gates. These changes are not contained in uploaded build 113;
they require a new committed source/export/archive/build before submission.
No Apple review submission or new store build is claimed here.
