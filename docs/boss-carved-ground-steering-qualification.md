# Boss carved-ground steering candidate

Gameplay/test source: `e9d8a1de95457a8182791536aa5e9fefeabe416c`, based on
the Magnet Court candidate `000d05bdb3d3854925ce3ccad6e7e1676a9cdf67`.

## Verified failure and change

Main CI run 37112314391 failed its Colossus ordinary two-peer match at source
`7b617be6394d32f4164d15fda21f2b11fa30f33c`. The host, not just the guest, reported
`colossus round 0 ended without actual boss defeat`. It had inflicted 715 of
800 health damage before the 150-second round ended. The guest's `host_left`
was a consequence of host failure. Artifact provenance confirms push/main,
that commit, clean tracked source, and seed 89477456.

Separately, a regression fixture proves that BossHunter's straight steering
crosses an intervening crater during approach and warning escape. A new floor
query samples safe short movement segments. Bots use it for approach/escape
on carved ground and retain the ordinary steering path in other arenas. Aim
error remains, but unsafe error-adjusted steps are rejected. The network
fixture now reuses the same floor query instead of maintaining a duplicate.
Health, arm damage, exposure time, round length and peer watchdogs are unchanged.

This is local obstacle-aware steering, not a complete global path planner or
a guarantee against inertia, knockback or dash falls. The original Colossus
completion failure remains unproven fixed until a complete peer run passes.

## Tests

- Identical Colossus approach fixture on previous brain: 90 passed, 14 failed,
  exit 1. Corrected brain: all 104 assertions pass, exit 0.
- Physical crater floor, collider/reset/presentation plus safe-step and
  thin-margin escape checks: 75 assertions pass, exit 0.
- Colossus network capture/authority suite: 152 assertions pass, exit 0.
- All 324 scripts compile; `git diff --check` passes.
- Node server suite: 144 discovered, 138 pass, 6 explicitly skipped, zero fail.
  These six require generated Godot world fixtures; this local invocation
  does not claim them tested.
- 691 tracked source/data/test/server/project files match the runtime clone
  byte-for-byte. Ignored Python cache files are not release inputs.

Runtime: `/tmp/kras-cloud-export-uid-check`; baseline:
`/tmp/kras-keeper-baseline-check`. Logs:
`/tmp/kras-carved-steering-baseline.log`,
`/tmp/kras-carved-steering-approach.log`,
`/tmp/kras-carved-steering-floor.log`,
`/tmp/kras-carved-steering-network.log`,
`/tmp/kras-carved-steering-compile.log`,
`/tmp/kras-carved-steering-server-tests.log`.

Old failed CI artifact: `/tmp/kras-colossus-main-failed-artifact/_temp/`,
including `kras-qa-source.json` and the original host log.

The initial fixture launch failed GDScript type inference for test locals;
explicit Vector3 declarations were added before the baseline/final runs above.
The initial real-peer launch lacked the `ws` package and exited before opening
peers. `npm ci --ignore-scripts` installed the pinned two dependencies, reporting
zero known vulnerabilities; this does not establish application security.

## Real peer qualification

The current controlled two-peer reproduction uses seed 89477456, ordinary
rounds and reconnect through the real WebSocket service. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-KUO3bz`.
Summary log: `/tmp/kras-carved-steering-real-peers.log`.

Terminal result: FAILED, exit 1, `2-players-0 timeout` at the existing 450-second
process deadline. Round zero had actual boss defeat; round one had damage and
its last sample was elapsed 35.4833, health 580, time remaining 114.5167. The
shared Mac's host frame gap reached 17598 ms and server loop gap 3242 ms. Both
peers loaded and the guest reconnected, but the full two-round match did not
complete. No complete-match PASS, 60-FPS, production or release claim follows.
The process was allowed to reach its own terminal watchdog; it was not manually
cancelled or restarted because a polling observation timed out.

## Parent-source CI proof

Magnet candidate run 37123850830 has a successful Core job. Downloaded
`/tmp/kras-magnet-urgent-core-ci/_temp/kras-qa-source.json` proves intended head
000d05bdb3d3854925ce3ccad6e7e1676a9cdf67, clean merge checkout
85a4ef4026902541cc16214f5736e4783e8ad8df and tree
be91a20c5ab624f0037a7cd512b33de436abada3, matching that source commit's tree.
Its full Godot suite passes 21569 assertions, 324 scripts compile and server
capture tests pass 144/144 with zero skipped. These qualify the parent source,
not the new carved-ground change. The remaining 39-game network matrix was
still live at the last check; its Core success is not whole-matrix success.

No automatic main merge, Railway activation, signed archive, Apple upload or
App Review submission is authorized by this qualification document.
