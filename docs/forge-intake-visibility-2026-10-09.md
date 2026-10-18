# Forge feeding target visibility

The original intake mesh has outer radius 1.6 inside the opaque furnace shell
of radius 2.6. Actual portrait rendering showed no readable feeding target.
Added one fixed emissive collar outside the shell, inner radius 2.62, outer
radius 2.9 (matching the existing cap silhouette), height 1.5. It has no
collision children. The original animated intake, transform, feeding reach,
damage, timers, RNG and replicated rotations are unchanged.

Both actual host and guest fixtures check visibility geometry and unchanged
feeding anchor. The existing real hit/replica tests remain intact. Targeted
forge_network suite: 151 assertions passed, exit 0. The first run had two
failed exact upper-bound comparisons because TorusMesh stores floating-point
radii; the corrected test uses is_equal_approx against the intended 2.9.
The first failed log remains /tmp/kras-forge-collar-tests.log.

All 444 scripts compiled. Actual Metal renderer captured boss_forge after
10 seconds, one touch human/three bots, Arabic, 1280x720 and 540x960:
both passed. Portrait image independently inspected; collar visible and
controls unobstructed. This is not iPhone performance, final graphical polish,
all-game balance or production networking proof.

Passing logs: /tmp/kras-forge-collar-tests-recheck.log,
/tmp/kras-forge-collar-compile.log, /tmp/kras-forge-collar-visual.log.
All passed the repository strict checker; sandbox CA diagnostic retained in
headless logs. Screenshots/report: /tmp/kras-forge-collar-visual-save/.

New simulation fingerprint:
53cde46b50cf16a86a63439072b716dfbf475238dfca1ef42a671d5bc384b552.
The ongoing 37939933912 balance campaign remains on its original a3358777
source and is not cancelled or relabelled. A complete regression check of
this new source remains required. No main merge, deployment or Apple upload.

## Completed current-source Core check

Run [37944511261](https://github.com/shary17454/kras-pass/actions/runs/37944511261)
completed successfully. Downloaded source evidence matches commit
a69a76ad64d6ed800153396fb7c6d7e80735c690, tree
1873468c952b60a3dea18ee6ff27698574297c40 and intended head, with no tracked
changes. Independently checked: 444 compiled scripts, 406153 completed
assertions, 117 shortened stability matches with empty failure lists,
275 server tests passed with zero skipped after actual Godot captures.
All 23 artifact logs passed the repository checker with their proper modes.

Four actual engine peers completed a three-round mixed tournament. All agreed
on round histories, final points [5, 9, 12, 8], champion slot 2 and completion.
Host and one guest reconnected. This remains localhost evidence, not Railway.
Raw artifacts: ../qualification-core-a69a76a-2026-10-09/.

The pre/post seeded Forge host capture differs only in process-local instance
IDs: forge_replica obtains these with get_instance_id. After independently
checking unique decimal-string IDs, all remaining captured fields deep-match
the prior 7681393 fixture. This is one fixture, not all-match determinism.
The original unnormalized comparison failure is not an engine test failure.

Core regression requirement for this change is now satisfied. Natural balance,
physical device acceptance, production data authorization and deployment,
final native archive and Apple upload/review remain separate open gates.
