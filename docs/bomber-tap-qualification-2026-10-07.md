# Bomber tap qualification

Runtime source: `8e5ac07a3675fff395e1bb10a182031dd59aaa6d`.
Branch: `fix/kras-bomber-tap-throw`, parent draft PR 187.
No main merge, production rollout, native install, upload or Apple submission.

## Repair

Fawda's real `_read_throws` consumes ATTACK `just_pressed`, while Bomber sent
held `press` requests. A prior shove followed by pickup can therefore prevent
subsequent throws. Only the holding-bomb attack requests now use `tap`.
Ordinary shove, pickup logic, fuse, damage, movement, perception and difficulty
profiles are unchanged. Four-tier regression runs the real controller and
virtual InputRouter, with stationary fighters and timing/noise isolated.
It starts with a held shove and requires three subsequent pickups to be thrown.

## Evidence and limitations

The first fixture omitted the controller link and incorrectly fell back to the
generic brain. Both initial failed logs are retained and are NOT valid evidence
of the runtime repair (`/tmp/kras-bomber-tap-red.stdout`,
`/tmp/kras-bomber-tap-green.stdout`). The corrected fixture assigns the actual
controller before configuring the brain. With original held requests it failed
all four tiers: 34 passed, 4 failed, zero throws instead of three.
`/tmp/kras-bomber-tap-red2.stdout`.
With tap requests: 38 passed, verbose shutdown and strict log guard passed.
`/tmp/kras-bomber-tap-green2.stdout`.
Compilation: all 420 scripts passed (`/tmp/kras-bomber-compile.stdout`).
Fawda round-evidence suite: 13 passed, strict guard passed
(`/tmp/kras-bomber-fawda-evidence.stdout`).

One diagnostic invocation without explicit writable `--log-file` crashed
before project startup while opening sandbox-inaccessible user logs.
`/tmp/kras-bomber-fixture-debug.stdout` is retained as a failed environment
attempt, not omitted or called a successful product test. Subsequent runs use
explicit temporary log and isolated save paths.

Natural source fingerprint (272 independently validated files):
`f2a3888bd8b301928cc943aacad789f0d4412a7c9c7c2f69633e683bb449f2b1`.
Offset 1200000: 24 baseline + 16 verified paired difficulty + 2 mutator smoke
matches, 42 total, no ties. Expert share 0.51875, character bias 0.0833333,
slot bias 0.0416667. The expert-no-better-than-easy warning remains.
Parent same-seed share was 0.50. This limited sample does not establish
general improvement or resolve the earlier leader-target regression.
Raw: `docs/qa/bomber-tap-2026-10-07/fawda-1200000.json`.
Balance review and release readiness remain false.

## Remaining gates

A fresh full QA gate on this source is not completed. Parent's full gate failed
on an exit ObjectDB leak. The separate frozen-parent verbose full assertion run
completed: 389921 passed in 467.4 seconds and strict log guard passed, with no
exit leak warning (`/tmp/kras-full-leak-diagnostic.stdout`). This does not
establish the earlier leak's cause or qualify the new Bomber source. The earlier
failure remains recorded; no suppression or test threshold changes were made.
Neither parent QA nor this focused suite qualifies a current
native archive, phone performance, production online, or App Review submission.
