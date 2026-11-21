# Party touch ownership qualification - 2026-10-16

## Change

TouchSource previously cleared full-screen reaction input when any owning finger
released. Steering and throttle likewise tracked the last event instead of the
remaining owners. Releasing one finger could cancel another held finger.

Reaction actions now remain held until their last owner releases. Steering is
recomputed from active owners: opposing directions cancel, duplicate fingers do
not outweigh the opposite direction, and throttle remains active while owned.
No save schema, network protocol, game rules or character stats changed.

## Reproduction and regression coverage

- Initial focused reproduction: 15,525 assertions passed, five failed.
- Expanded reproduction against the original TouchSource: 17,086 passed,
  69 failed. This includes public viewport-dispatched duplicate-finger events.
- Final focused suite: 17,155 assertions passed, exit 0.
- Existing input-source suite: 455 assertions passed, exit 0.
- Compile check: 467 scripts, exit 0.
- Full fixed-60-FPS headless suite: 445,263 assertions passed in 1484.8 seconds,
  exit 0. The strict completed-log guard passed.

The new suite covers 39 registered game control definitions x 1-4 touch players
x two starting resolutions (540x960 and 1280x720) x handedness on/off: 624
configurations. It dispatches actual viewport touch/drag events through
TouchSource and InputRouter, verifies isolation between players and held input,
and rotates the window while controls are held to verify release/reset.

This is input-fixture coverage, not 624 complete 3D matches. It uses default
positions and scale 1.0; it does not qualify every custom layout, tablet aspect,
physical touch ergonomics, controller hardware, battery, temperature or FPS.

The full log contains four deliberate error fixtures: one failed-save write
(`test_save.gd::_failed_write`) and three router recovery failures
(`test_router_recovery.gd`). Their backtraces were inspected; no unexpected
parser, script, assertion or resource-leak failure was accepted.

## Source and evidence

Parent: local commit `a2bc2da`; branch `feature/kras-online-random-rotation`.
Selected gameplay-source fingerprint before:
`cb22e0abe5d98a8cd2fe0d1ab315181712ace70b12bd5de0164bf60cdbc43a79`.
After:
`a8ce803e9ee28691fd02370bd10dbdef01c413cca9ed88600d924d718b350135`.
This fingerprint excludes tests, assets, server and native export/signing files.

Synthetic logs and source attestation are preserved beside the checkout in
`qualification-party-touch-2026-10-16/`; the logs retain their October 15 campaign
label. No private save directory is included.

## Remaining gates

Stage 0 remains QA_PENDING/MERGE_PENDING. Character balance acceptance, full
content qualification and physical iPhone/iPad checks remain outstanding.
Production deployment requires approved database backup/restore evidence.
This local fix does not imply GitHub synchronization, Railway deployment,
signed iOS archive, upload, processing, submission or Apple approval.
