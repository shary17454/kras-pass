# Restored Zone Hold fixture review - 2026-11-21

## Verdict

The original restored patch required the fixture eligibility correction below.
The corrected fixture now passes the recorded seed twice on an isolated host
(six matches), plus the earlier CI seed. No runtime change was justified or
made. Shared-load failures remain retained; exact CPU/transport causality for
their unscored eligible guest is not established by the older sparse logs.
See the latest isolated diagnosis at the end; earlier statuses are historical.

## CI evidence

PR #218 head: b3c01b54de14fb0fb971b50109bf4e48acd4f6dd.
Run: https://github.com/shary17454/kras-pass/actions/runs/40404504560
Failed job: https://github.com/shary17454/kras-pass/actions/runs/40404504560/job/121859412907

The ordinary two- and four-human probes passed. The next, tournament probe
failed in epoch 3, seed 1515907195, after finishing the third match. The guest
received 2534 snapshots; the server loop maximum was 22 ms. At 9.483 seconds
remaining, scores were [0,0,1,1]; at zero they were [3,0,4,1]. The explicit
failure was `local zone participant never captured: slot=1`.

This confirms missing participant capture at the match deadline, not a process
timeout or a missing result. The six-second fixture schedule gives turns to
autonomous bots that do not obey it. Holding an unscored human's input until
authoritative points appear is consistent with this evidence. Sparse diagnostic
snapshots alone do not prove every intervening movement or rule out all other
causes. The recorded failing match still needs a real multi-peer rerun to prove
the repair end to end; a unit pass is not that proof.

## Soundness

- `capture_owner` prioritizes only configured participant slots with zero or
  negative points, provided the score vector matches the roster length. With
  no usable score coverage request it retains the original timer behavior.
- `human_competitor_slots()` includes remote humans identified by online peer
  IDs, not just the current process's local human. Normal network roster order
  is shared, so equal score snapshots produce equal ownership decisions.
- Guest scores are populated by the host replica. Snapshot delay can briefly
  postpone handoff but does not fabricate capture. Scores are nondecreasing
  within a Zone Hold round and reset normally between rounds/matches.
- The pilot only returns movement/attack inputs. It does not write scores,
  fighter positions, runtime rules, duration, AI, or networking authority.
- Existing per-participant capture checks still run before tournament advance.
  No assertion, tolerance, process deadline, or fixture duration was relaxed.
- Priority is a coverage policy, not a fairness or liveness guarantee against
  arbitrary autonomous opponents. Network smoke remains the integration gate.

## Tests and scope

The restored additions cover timer boundaries, actual participant slot identity,
host/guest local-device differences, the recorded [3,0,4,1] failure, resumed
rotation, direction of input, and read-only score/body behavior. They contribute
31 executed assertions: 7*3 + 2 + 2*2 + 4, not the reported 38.

`git diff --check` passed for the three reviewed files. After the shared import
completed and its strict log guard passed, the focused Zone Hold suite passed
4816 assertions in 0.9 seconds, exit 0, on Godot 4.7.1. Both the engine log and
stdout passed the tests guard; stdout also passed the runtime guard (no ERROR).
The initial sandbox attempt also passed 4816 assertions but emitted relative
log-path and macOS CA-access errors; its stdout is retained separately and is
not the clean qualification run. No second import was started by this review.

Command (absolute evidence/save paths were supplied to Godot):

```sh
godot --headless --fixed-fps 60 --path . --log-file "$EVIDENCE/unit-zone.log" tests/test_runner.tscn -- --suite=zone_hold --test-data-dir="$EVIDENCE/unit-zone-save-clean"
```

The user subsequently authorized Zone-only network smoke. Its `TMPDIR` is the
permanent evidence directory, so engine/stdout logs and per-peer isolated saves
are created there directly. No deadline was changed.

## Additional defect: Final Eligibility

The restored patch's two-peer tournament with seed 1515907195 failed, exit 1.
Evidence: `kras-network-smoke-W88YGD/` and
`zone-recorded-seed-1515907195-tournament.stdout`; structured round/failure
extraction: `recorded-seed-spectator-proof.json`.

Both peers agreed on these scores:

- Epoch 1: [1,1,3,3], both humans captured.
- Epoch 2: [3,1,4,4], both humans captured.
- Epoch 3: [3,1,2,2], both humans captured, including the original failing case.
- Epoch 4: [0,0,3,7], both humans were spectators, not active contenders.

The scoring change altered tournament standings and exposed a bot-only tie
final. `_finished` already derives `spectator` from the immutable match config's
`online_contenders`, but the Zone-specific condition at line 1776 ignored it.
It demanded capture from excluded humans who correctly remained inactive and
scored zero. This is an eligibility-contract defect in the fixture, not a
runtime capture failure. Simply skipping checks when `alive == false` would be
wrong: active humans may temporarily fall and respawn.

The actual rule is `online_contenders` (not a `final_contenders` field):
`server/tournament.js` selects tied leaders, `Net.make_match_config()` copies the
validated tournament contenders into this per-match rule, and
`MatchScene._begin_play()` eliminates/hides all excluded fighters. The driver
uses world coordinates only and does not read the camera, HUD, viewport, or
screen-space layout. The independent UIKit layout issue is not a data dependency
of this failure. No UI capture was necessary; the headless state metrics above
preserve the relevant evidence without rendering or modifying UI.

Required correction: intersect humans with configured final contenders for
capture ownership. Keep positive observed-and-final-score evidence mandatory
for every eligible human. For an explicitly excluded online human, instead
assert inactivity, zero final points, and no observed capture. Add focused
negative tests so death, stale observation, unexpected points, malformed
contenders, and an eligible but unscored final participant cannot bypass checks.

The unmodified restored patch also failed the CI tournament seed 1082281558:
epoch 4 returned [1,0,16,0], with the host participating and the guest an excluded
spectator. Evidence: `kras-network-smoke-23S99r/` and
`zone-ci-seed-1082281558-tournament.stdout`. Both failures are retained.

## Eligibility Correction

Only the three authorized test scripts were changed. The fixture now derives
`active_participant_slots` by intersecting network humans with the immutable
match config's `online_contenders` when present. It does not filter temporary
deaths out of the capture obligation. `_finished` checks the tested shared
`capture_evidence` contract and logs configured contenders, all network humans,
active participants, local liveness, observed capture, and final scores as
`NETWORK_ZONE_COVERAGE`.

There is no unconditional spectator skip: eligible humans need both observed
capture AND positive final points. An excluded human needs a nonempty online
final config, inactive state, zero points, and no observed capture. Invalid or
duplicate contender slots, invalid local slot, missing score vector, and bots
cannot satisfy this human evidence contract. The existing general spectator
inactivity assertion remains in place too.

Added 29 focused assertions; Zone Hold now passes 4845 assertions in 1.0 seconds,
exit 0, with clean engine/stdout tests guards and a clean stdout runtime guard.
Logs: `unit-zone-eligibility.{log,stdout}`. Source hashes and corrected patch:
`eligibility-inputs.sha256`, `zone-eligibility-review.patch`.
The corrected original-seed tournament FAILED, exit 1, before reaching its final.
Evidence: `kras-network-smoke-69snjp/`,
`zone-eligibility-seed-1515907195-tournament.stdout`, and
`eligibility-seed-1515907195-proof.json`. Epoch 1 passed with [3,1,4,1]. Epoch 2
ended [1,0,1,4]; config contenders were empty, active humans were [0,1], and the
guest was alive but had no observed capture. The strengthened condition correctly
rejected that eligible unscored guest. The host's later `closed left` is secondary
to the guest failure, not the root cause. The score-aware pilot is therefore NOT
a sufficient liveness repair for every real bot-contested 30-second match.

This is separate from the spectator bug and remains a qualification blocker.
No duration, deadline, runtime rule, bot behavior, score, or position was changed
to turn this failure into a pass.

## Final Run and Freeze

Corrected CI seed 1082281558: PASS, exit 0, two real peers, three matches,
both peers captured in every match. Both peers agreed on [3,1,6,0], [1,1,2,3],
then [1,1,5,1]. Final points: [7,6,13,8], champion [2], complete=true.
Both peers reconnected; the guest received 2568 snapshots/world snapshots.
All four engine/stdout logs passed the strict runtime guard. Server loop peak
was 3024 ms, so this shared-machine run is not performance qualification.

Evidence: `kras-network-smoke-GqxIUx/`,
`zone-eligibility-seed-1082281558-tournament.stdout`, and
`eligibility-seed-1082281558-proof.json`. The tournament ended without a tied
final (`tie_attempts=0`); the corrected spectator acceptance path is covered by
unit tests, NOT by a successful real spectator-final run in this review.

The earlier bot-only and mixed-final actual failures establish the eligibility
bug, while the corrected original-seed failure establishes a separate remaining
active-capture blocker. The restored patch required this test-only eligibility
correction but still cannot be called fully network-qualified. No more retries
or pilot tuning were attempted after the requested source freeze.

All three test-source hashes still match `eligibility-inputs.sha256` after the
final run. Sources are frozen for the parent's full suite/archive. This review
started no full suite, archive, UI run, commit, push, deployment, or heavy import.

## Resumed Isolated Diagnosis

The user reopened the source freeze for diagnosis and paused other campaigns.
Only optional fixture tracing was added: `KRAS_ZONE_TRACE=1` emits at most one
sample per 250 simulated milliseconds. It records host positions/velocity,
occupancy, capture accumulator, owner, scores, guest pilot input, and (in run 03)
the last received remote packet and its age. Without the environment flag there
is no extra trace output. No scoring, movement, bot, authority, duration, or
assertion behavior changed during this resumed diagnosis.

The first trace attempt had a GDScript inference error in the logger, was stopped,
and is retained as `kras-network-smoke-pckPN8/`; it is not behavioral evidence.
The explicit Vector3 annotation repaired that diagnostic-only error.

### Actual Load Windows (Riyadh)

- Isolated run 02: actual processes started 12:41:15; completion observed
  12:44:08. Process snapshot showed only this host and guest, no other Godot
  campaigns. PASS, exit 0; scores [1,1,4,3], [4,1,2,2], [2,1,2,2].
- Isolated run 03: start approximately 12:45:29; completion observed 12:48:12.
  Pre-run process snapshot showed no other Godot/network campaigns. PASS,
  exit 0; scores [2,1,6,3], [2,1,3,3], [3,1,5,4].
- Both peers reconnected in both runs. Each guest received 2568 world snapshots.
  All eight engine/stdout files passed the strict runtime guard. Server loop
  maxima were 72 ms and 48 ms. No network process remains running for this work.

Run directories: `kras-network-smoke-saLicM/`, `kras-network-smoke-UCwXIq/`.
Summary metrics: `zone-idle-run02-trace-summary.json`,
`zone-idle-run03-trace-summary.json`. Unit rerun remained 4845 assertions, exit 0,
with clean tests/runtime guards (`unit-zone-trace.{log,stdout}`). Reviewed source
hashes, including unchanged runtime Zone/AI/replica, match
`trace-reviewed-inputs.sha256` after the last run.

### What the Trace Proves

The earlier failing epoch 2 had the guest waiting at 4.90 m from the zone at
12.62 simulated seconds, while slot 0 was still unscored and slots 0/2 contested
the zone. At 22.62 seconds, ownership had passed to slot 1, but that guest was
15.39 m away, outside the 3.4 m zone, with 7.38 seconds remaining. Slot 2 occupied
the zone at that sample. This is not evidence that Zone refused a point from an
uncontested guest. Exact handoff/input times are missing in the old 10-second
diagnostics. Extraction: `zone-original-eligible-failure-position-proof.json`.

Across the six idle matches, sampled handoff to the guest occurred at 10.016 to
16.016 seconds. Every guest reached the zone and scored. The slowest idle case
first entered alone at 11.016 seconds but did not reach a point until 19.766:
intervening bot contests consumed the margin. In run 03, remote packet age was
at most 37 ms across all 360 host samples, with zero expired samples; Zone's
capture accumulator advanced only on the authoritative host.

Authority audit: guests publish local input then render snapshots and return
without ticking rules; the host consumes remote input, ticks fighters/AI, then
Zone. Remote humans have no AI brain. Zone intentionally pauses when occupancy
is not exactly one, and awards a point at accumulator >= 1. The bot brain can
contest, shove, and dash while the fixture stages other humans. The fixture
does not guarantee capture merely by granting a turn.

Important diagnostic distinction: the router poll resets a remote slot before
the match consumes network input. Run 02's `move`/`bits` fields sample this
pre-consumption router state, NOT the applied remote input. Run 03 explicitly
renames them `router_*_before_match` and separately logs `received_axes`,
`received_bits`, and `received_age_ms`; zeros in the old router sample must not
be interpreted as lost packets.

Classification: the observed failure is a timing-sensitive scripted coverage
shortfall, not an established product scoring/authority defect. Contention and
late turn availability are observed; host-load/input staleness is a plausible
additional contributor, not a proven root cause of the old failure.
`Net.INPUT_EXPIRY_MS` is 250 and intentionally clears stale input; existing
network regressions cover that contract. It was neither changed nor bypassed.
Two idle successes do not prove universal reliability under arbitrary load,
and no concurrent-load qualification is claimed. No runtime fix is warranted
without a reproducible violation of the scoring or authority contract.

The recorded-seed isolated gate is now green twice; full-suite/archive and
release gates remain owned by the parent. The real corrected spectator-final
success path is still not exercised by these untied idle tournaments; its
positive and negative contracts remain covered by the focused unit suite.

Permanent evidence directory: `../qualification-release-20261121/network/`.
It contains the decoded GitHub job log, the exact reviewed unstaged patch, and
SHA-256 hashes of all three input files. No commit, push, production operation,
or UI test was performed by this review. No full Godot or server suite was run.
The separately reported server result (270 pass, 6 skips) was supplied by the
user and is not independently reverified here.
