# Driver ram alignment experiment

Parent: `be03d53511503c1f4ddee90b7d2165f51fef5faf` (gameplay identical to
`968aab7829e5a8484f540a710c67f96adfe68d19`).
Candidate: `9887d05f78aeb8b7bb9f6708ed3a53baf7933ec2`.

## Decision

Do not adopt this candidate as a balance repair. It suppresses ram commitments
when the nose is not within approximately 37 degrees of the observed rival,
but the held-out comparison does not support improvement. Parent gameplay and
the engagement suite were restored after qualification. Do not ship this candidate
on the strength of the geometry fixture alone.

## Evidence and limits

DRIVE dash impulse follows `Fighter.facing`, not the requested steering vector.
The original Driver requests a dash based only on range and speed. The fixture
reproduces eight away/sideways requests across four tiers. It overrides the
observation and `maybe_dash` request collector, not steering. This tests a
proposed commitment policy, not natural AI perception, damage or balance.
The 0.8 alignment threshold is a design choice, not an existing invariant.

Focused original: 41 passed, eight failed,
`/tmp/kras-driver-ram-red-isolated.log`.
Candidate with overlap, visibility, speed, range and edge recovery guards:
57 passed, strict log guard passed, `/tmp/kras-driver-ram-green.log`.
Actual vehicle impulse/projection suite: 29 passed, strict guard passed,
`/tmp/kras-driver-ram-vehicle.log`.

The first command omitted `--log-file` and failed to open user storage before
tests, then Godot exited 134 with signal 11. This is not RED evidence for the
policy. The isolated rerun is the actual RED above. A separate mistaken
`--suite=ai_perception` filter selected no suite and failed (0 pass, one fail);
it is not evidence of a perception defect. Both logs are retained.

## Natural matched comparisons

Each new report has 24 baseline, 16 matched difficulty and two stress matches.
Independent validation confirmed eight difficulty pairs and stable start/end
source fingerprint: 274 files,
`f6021dbbb081690ef807803392db933a2b85de36f1101d2ad4525be3e63ecc18`.
Both runs exited zero and passed strict runtime guards. Total: 84 new matches.

| Source | Offset | Expert share | Character bias | Seat bias | Warning |
| --- | --- | --- | --- | --- | --- |
| Parent runtime | 1200000 | 0.493750 | 0.083333 | 0.083333 | Expert no better than Easy |
| Candidate | 1200000 | 0.500000 | 0.041667 | 0.125000 | Expert no better than Easy |
| Parent 968aab7 | 1500000 | 0.596273 | 0.041667 | 0.041667 | none |
| Candidate | 1500000 | 0.559006 | 0.083333 | 0.166667 | none |

All baseline tie rates are zero. These small cohorts do not establish
statistical causation; they also do not justify calling the candidate a
balance improvement. Validation `complete` means the selected game executed,
not that product balance or release acceptance is complete. Both reports have
`balanceReviewComplete=false` and `releaseReady=false`.
Raw reports: `docs/qa/driver-ram-alignment-2026-10-07/`.
Parent reports remain in the prior current-source and facing-backoff reports.

## Release gates

The candidate full gate completed with exit zero:
`/tmp/kras-party-check.NZSABS`, wrapper `/tmp/kras-driver-ram-full-gate.log`.
421 scripts compiled; inventory: 521 resources, 22 autoloads, 27 routes,
eight characters, zero issues. Test suite: 390243 passed in 417.2 seconds.
Actual race regression and all six boss regression invocations passed their
strict guards. One stability cycle: 39 matches, zero failures. This is not a
long-running soak or physical-device qualification. Intentional negative-save,
router and memory-warning tests retain diagnostics; native CA access warnings
also remain. Do not describe the entire log as error-free.

Server tests initially failed because sandboxed localhost listening returned
EPERM (`/tmp/kras-driver-ram-server-tests.log`). A local-permission rerun used
all six world captures from this exact gate: 204 passed, zero failed/skipped,
1482.2 ms (`/tmp/kras-driver-ram-server-tests-local.log`). No production state
changed. These checks qualify execution, not natural balance superiority.

The candidate tests remain available in commit 9887d05; they are not present
in the restored final tree. No candidate online-four-client acceptance is
claimed. `git diff --exit-code be03d53511503c1f4ddee90b7d2165f51fef5faf --
src tests tools data scenes project.godot server` passed after restoration.
The original engagement suite passed 25 assertions in 2.6 seconds with the
strict log guard: `/tmp/kras-driver-ram-restored.log`.

All39 campaign 37670303689 remains on d5524b9, not this candidate. It was
confirmed live with 16 completed jobs and two running jobs during this turn.
No main merge, protected production data operation, Railway deployment,
device installation, archive, upload or App Review submission occurred.
The Scrap Expert deficit remains open. The next investigation should separate
dash request publication from target geometry: consecutive held DASH requests
may not create the `just_pressed` edges consumed by Fighter. Verify it with
actual InputRouter and cooldown integration before changing the shared helper.
