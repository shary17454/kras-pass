# Sweeper visible contact qualification

## Source and defect

Runtime source: `9d952fbba4d79fde1538109ac62f4f6e96c90996`.
Parent: `4c57960544a29dc37f5267392dc8b6def45c0c39`.
Godot: 4.7.1 official a13da4feb, macOS.

The blade was rendered with dimensions `(length, 0.45, 0.7)` but its
Area3D box used `(length, 0.9, 0.8)`. This created invisible contact above
and beside the blade. Collision size and local centre now come from the
actual mesh AABB. Impact power, direction, character stats, difficulty
profiles, jump timing, rotation schedule and network message schema are
unchanged. This is a gameplay collision correction, not just an AI change.
The collider remains a box around the mesh bounds, not a triangle-accurate
representation of its beveled corners.

## Physical regression

`tests/suites/test_sweeper_visible_hitbox.gd` uses actual Fighter capsules,
actual Area3D overlap and `Sweeper.tick()` at three different rotations.
It checks clearance above and beside the rendered blade, as well as genuine
contact still producing a hit. Teleports settle for four physics frames:
shorter waits were insufficient for reliable Area3D overlap updates.

With the final identical fixture and original runtime implementation:
10 assertions passed and 15 failed, exit 1. With the corrected runtime:
25 passed, exit 0. Counters reset between clearance cases, avoiding cascading
failures. Evidence:

- `/tmp/kras-sweeper-hitbox-red-final.log`
- `/tmp/kras-sweeper-hitbox-green-final.log`
- `/tmp/kras-sweeper-hitbox-impact.log`: 31 assertions passed.
- `/tmp/kras-sweeper-hitbox-network.log`: 26 assertions passed.
- `/tmp/kras-sweeper-hitbox-perception.log`: 117 assertions passed.
- `/tmp/kras-sweeper-hitbox-compile.log`: all 381 scripts compiled.

All successful focused logs passed `tools/check_godot_log.sh`.

## Natural balance evidence and remaining issue

Each sample consists of 24 baseline rounds, 16 matched-seed/character
difficulty comparisons and two mutator/chaos smoke rounds. No round duration,
character strength or report threshold was weakened to obtain a pass.

At seed offset 600000, the parent expert score share was
0.447204968944099; corrected contact yields 0.54375. Mean baseline round
duration changes from 24.6659722222217 to 30.9999999999992 seconds.
The expert-underperformance flag clears, but `character advantage` remains.
Baseline wins: fanoos 2, mowja 5, sakhra 7, turs 10.

An independent corrected-source sample at offset 900000 produces expert
share 0.559006211180124 and mean duration 23.2770833333328 seconds.
`character advantage` remains: barq 1, fanoos 2, mowja 2, ramla 1,
sakhra 12, turs 6. Neither sample proves all-character balance or READY status.

- Parent report: `/tmp/kras-dodger-independent-report/report.json`
- Matched corrected report: `/tmp/kras-sweeper-hitbox-balance-report/report.json`
- Independent corrected report: `/tmp/kras-sweeper-hitbox-independent-report/report.json`

## Four-peer local networking

Four actual Godot engines and a temporary local WebSocket service ran seed
438683058 on the committed runtime source. All peers moved and agreed on
scores `[8, 8, 16, 8]`. Host and one client reconnected; client world snapshot
counts were 715, 734 and 734. Maximum measured server-loop interval was 28 ms.
The process exited 0 and the runtime log guard passed.

Evidence: `/tmp/kras-sweeper-hitbox-four-peer.log`.
These are automated input peers, not four real people, Internet qualification
or iPhone battery/thermal measurements. Production online is not enabled by
this change.

## Release and device boundaries

The local Xcode 27 device inventory now reports physical iPhone
`00008140-000E7D291E98801C` connected. The sandboxed inventory initially timed
out; the authorized macOS-local inventory succeeded. App inventory did not
report Kras Pass. No app was installed and no current-source gameplay was
tested on that phone in this qualification.

Keychain contains the existing Distribution identity
`C81811A21B592B030D57CD5B180227BDDADEA4C1`. Existing Kras Pass Store profiles
match team 4HM66AD594 and `com.shary.kraspass`. The existing device QA profile
469a0687-f6f1-4b5a-bfb6-5ec2584fdfc0 includes the phone and the installed
Development identity. No P12 was imported and no certificate was created,
revoked or replaced. Identity/profile availability is not signing evidence.

No current-source Archive, codesign validation, App Store upload, processing
or review submission has been performed. The user's subsequent Git request
takes priority over starting the device build. The detached device-source
checkout is `/tmp/kras-sweeper-device-source-9d952fb`; it has not been exported.

## Full regression

Full `tools/check_party.sh` completed against the committed runtime source,
exit 0. All 381 scripts compiled, inventory found 421 resources, 21 autoloads,
27 routes and eight characters with zero inventory issues. The full suite
passed 360494 assertions in 783.8 seconds; the independent three-lap race
regression and all six boss probes passed. One stability cycle completed
39 matches with zero failures. The cycle uses shortened non-race clocks;
race laps remain unchanged. It does not prove long-session leak freedom.

After the explicit memory warning and five-second drain, native Godot static
memory remained 441289134 bytes. This is not process RSS, VRAM, an iPhone
memory measurement or proof that residual memory is fully attributed.
The isolated macOS runs emit the engine's existing system-CA-certificate
startup error; no claim of completely error-free engine logs is made. The
GDScript/runtime log guards and all pipeline gates passed. These tests do not
substitute for production TLS/auth checks.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.z2rDJY`.
The final report commit adds documentation only; runtime evidence belongs
to the exact source commit above. No release or device qualification follows
merely from these test results.
