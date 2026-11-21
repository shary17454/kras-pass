# Sweeper opening contact repair

## Confirmed defect

On parent commit `34314a0b463d35f754283ff59ce31c82312c5404`, the match
spawns fighters above the floor. Intro/countdown do not advance their movement;
physical landing starts at PLAYING. Jump requires is_on_floor(), while the
newly randomized sweepers could hit during that initial fall.

A separate read-only Node/TSCN diagnostic used the actual MatchScene, natural
intro/countdown, four Expert bots, and the 24 canonical seeds/character rosters.
It observed only the first 60 physics ticks, not completed matches:

| Observation | Before | After |
|---|---:|---:|
| Identical starts | 24 | 24 |
| Environmental hits in first second | 41 | 0 |
| Starts with those hits | 17 | 0 |
| Hits before tick 15 | 8 | 0 |
| Those early hits with is_on_floor=false | 8 | 0 |

The initial six-tick observation had no hits and was insufficient to diagnose
the defect. The longer floor-aware observation established it. Before/after
seeds and rosters were compared directly and match.

## Scoped repair

SweeperStorm assigns a one-second opening_grace from tuning. Sweepers continue
to rotate and accelerate, but do not apply contact hits during that interval.
Other modes retain the default zero grace. Existing reset_hazards resets _age
for each round. The interval is bounded to 0..2 seconds.

No character statistics, resistance influence (still 0.25), AI parameters,
random draws, scoring, timeout, save format or network payload were changed.
The physical overlap test explicitly repositions the probe at the rotated arm
and waits for physics before confirming that contact hits resume.

## Verification

Godot 4.7.1-stable (official), isolated imported runtime
`/tmp/kras-tank-pursuit-check`, same four source/test edits as the checkout.

| Check | Result |
|---|---|
| Sweeper impact regression | 118 assertions, exit 0 |
| Full Godot suite | 408190 assertions, 605.0 seconds, exit 0 |
| Compile check | 450 scripts, exit 0 |
| Sweeper replica/network contract | 29 assertions, exit 0 |
| Local server suite with six actual current Godot captures | 276 passed, 0 failed/skipped, exit 0 |
| Strict stdout/engine guards for completed Godot runs | PASS |

The first server attempt had 266 passes and 10 failures: sandbox EPERM on
127.0.0.1 listeners. The approved local rerun passed all 276 without modifying
tests or using synthetic captures. Both logs are retained. The initial wrong
suite filter selected zero tests and failed; the corrected filter produced the
118-assertion result. Earlier diagnostic --script attempts failed before
autoload initialization and were terminated; switching the external diagnostic
to a normal Node/TSCN entry point resolved that setup error.

## Natural supplementary balance samples

Each row below is 96 natural baseline + 48 matched/mirrored difficulty + two
mutator/chaos smoke matches, all completed. Same default sweeper_ring arena,
four bots, unchanged acceptance thresholds. The 64M before/after baseline
seeds and character rosters match exactly.

| Sample | Character bias | Seat bias | Expert point share | Flags |
|---|---:|---:|---:|---|
| Before, offset 64000000 | 0.031250 | 0.083333 | 0.514583 | Expert no better than Easy |
| Candidate, offset 64000000 | 0.062500 | 0.052083 | 0.557173 | None |
| Candidate held-out, offset 68000000 | 0.072917 | 0.072917 | 0.572614 | None |

Both candidate smoke pairs pass. Candidate source fingerprint is unchanged
before/after both campaigns and matches the checkout:
`adbbda6d74c6f6d6fb5f508ec50970e3123381f34a38f28329759d57b75ad1dd`.
Parent/before gameplay fingerprint:
`be7952428ad72f69703dfa8d918427c7d8e42e1466d5007445c0a527c16316dd`.
Candidate runs were made on the four uncommitted edits above the named parent;
the final local commit records them after verification. The fingerprint covers
selected src/scenes/data/tools types and project.godot, not all assets, tests,
native binaries or an App Store archive.

These seeded_partition_seat_rotation samples are supplementary, not a replacement
for the canonical adjacent_rotation policy. Absence of flags in these samples
does not erase older warnings or prove long-term balance or human enjoyment.
Character bias increased slightly in the matched sample; it was not hidden.
The held-out sample was not used to retune the already chosen fairness repair.

## Evidence and remaining gates

Original JSON/HTML reports, opening observations, external diagnostic scripts,
failure/success logs and six server capture fixtures are preserved in
`../qualification-sweeper-opening-grace-2026-10-10/`.

The previous 1638-match canonical campaign and 39-game content classification
remain historical evidence for be795, not current candidate qualification.
Likewise network run 38022898755 uses c0a5b6c, not this candidate. A new canonical
campaign and current-source multi-peer qualification are still required.

No READY/DONE promotion, production database access/migration, main merge/push,
Railway deploy, physical-device performance claim, fresh signed archive,
App Store upload or review submission. Stage 0 remains QA_PENDING/MERGE_PENDING.
The earlier denied production promotion was not bypassed; approved durable
backup/restore and release/device acceptance remain external gates.
