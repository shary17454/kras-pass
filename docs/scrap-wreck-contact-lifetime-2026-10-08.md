# Scrap wreck contact lifetime

Source: `29c0c79a655a150dd28ea0885151fce77b2d2508`.
Parent: `3ed6a7fbc10805b2055d339ba060c10177ada5ee`.

## Reproduced issue

`_resolve_rams` checked the outer kart's life only before entering its pair loop.
Backwash could eliminate it in the first pair, yet the next pair still treated
its position as a ram collider. Elimination correctly zeros the kart's velocity,
so the first stationary-third-kart fixture passed and did not prove a defect.
When a third kart approached the now-dead collider, the real match fixture
reproduced damage from its backwash, a new pair cooldown, and duplicate ram
feedback: seven assertions passed and three failed.

The third kart lost health from 100 to 93.8285714285714 even though the other
kart had already been eliminated. This is a collision-lifetime defect, not proof
of the cause of the observed Easy/Expert balance warning.

## Fix and scope

Before each subsequent pair, stop the outer pair loop if its kart was eliminated.
The first live collision retains its damage/backwash/feedback. Mutual damage
within that collision is not interrupted. A healthy kart still processes both
nearby live collisions. No AI profiles, speed, damage budget, balance threshold,
sample window, controls or network schema changed.

## Verification

- Contact lifetime: 13 assertions pass, including the new dead/healthy cases.
- Existing Scrap network/damage presentation suite: 121 assertions pass.
- All 422 scripts compile.
- One current-source stability cycle: 39 matches, zero failures, cache release
  completes after the deliberately injected memory warning.
- Existing log guards pass for both completed test suites, compilation, natural
  simulation and stability. No logs were edited and no guard was weakened.
- Natural sample: 24 baseline, 16 paired difficulty, two successful stress
  matches. Seat wins `[4,10,5,5]`, Expert edge `0.50625`, ties zero. These match
  the earlier sample: `expert bots no better than easy` remains and is retained.
- Official Godot `4.7.1-stable`; simulation start/end fingerprint both
  `ef891f443408c595f6440a9e3d5d4dec8dc41fb1008be8e05894cf92e94ac524`.

The parent full gate's 390616 assertions and real Magnet network match do not
constitute a fresh full gate or four-client Scrap match for this new source.
At that initial check, those broader checks, further balance work and device
acceptance remained open. The current-source follow-up below closes the full
headless gate and four-client Scrap check only, not the remaining release gates.
No all-games READY claim, main merge, Railway mutation, archive, upload or
App Review submission was performed.

## Evidence

- Initial stationary diagnostic: `/tmp/kras-scrap-wreck-red-engine.log` (passes).
- Reproduced moving-third failure: `/tmp/kras-scrap-wreck-moving-red-engine.log`.
- Final regression: `/tmp/kras-scrap-wreck-complete-engine.log`.
- Existing network suite: `/tmp/kras-scrap-wreck-network-engine.log`.
- Compilation: `/tmp/kras-scrap-wreck-compile-engine.log`.
- Stability: `/tmp/kras-scrap-wreck-stability-engine.log`.
- Natural engine log: `/tmp/kras-scrap-wreck-1200000-engine.log`.
- Raw report: `docs/qa/scrap-wreck-contact-2026-10-08/natural-1200000.json`.

## Current-source network acceptance follow-up

Tested clean checkout `22b762b7ae1e4e20f506c4daadea3017a4caa10b`,
without changing runtime inputs. The first sandbox invocation could not bind
`127.0.0.1` (`listen EPERM`); it did not create a playable room. Repeating the
same test in the approved local macOS session completed with exit zero:

```sh
env GODOT_BIN=/opt/homebrew/bin/godot node server/network-smoke.js \
  --game=scrap_karts --humans=4 --seed=309019
```

Four real Godot clients had distinct player IDs, moved, and finished with the
same authoritative scores `[26,20,4,12]`. The host and a guest reconnected during
PLAYING. The three guests received 1394, 1394 and 1375 world snapshots. The
host submitted the result; the room closed after the intentional RESULTS-stage
host leave, not because its PLAYING-stage transport interrupted the match.

All four client engine logs passed the existing strict `import` log guard.
The server recorded 6393 input and 1394 snapshot operations, no operation
stalls, and a maximum event-loop delay of 97 ms. This local headless run does
not prove rendered 60 FPS, physical-device energy/thermal performance, Internet
play, production deployment, a tournament or every game's reconnect behavior.

- Runner log: `/tmp/kras-scrap-current-four-client-local-2026-10-08.log`.
- Client logs and timing: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Tsrh3s/`.
- Failed sandbox attempt: `/tmp/kras-scrap-current-four-client-2026-10-08.log`.

## Live Apple release inventory

The authenticated Chrome UI on 2026-10-08 identified Kras Pass, App Store
Connect app `6801506973`, with version `1.1.10` Ready for Distribution and
selected build `107`. TestFlight showed version `1.1.10`, build `107`, Ready to
Submit (80 days remaining), with older version groups and no `1.1.11` group.
App Review showed the latest `1.1.10` submission on September 28 as Review
Completed, and the earlier same-version submission as Removed; no pending
submission was visible to withdraw. No Apple metadata was changed.

The old local candidate 112 is not the current-source release. Its export
provenance verifier correctly returned exit one against this checkout. A new
source freeze, version/build commit, local Xcode 27 export/archive and signing
verification are required before upload. This inventory is not an upload,
processing result, new submission or current-build approval.

## Completed full regression follow-up

The existing `tools/check_party.sh` completed with exit zero against source
`22b762b7ae1e4e20f506c4daadea3017a4caa10b`. Only this documentation changed
during the run; runtime, test inputs and the source commit remained fixed.

- All 422 scripts compile; inventory checked 522 resources, 22 autoloads,
  27 routes and eight characters with zero reported issues.
- Full test runner: 390624 assertions pass, 611.3 seconds.
- Separate party race regression passes.
- Six separate boss AI checks pass (three Colossus seeds, Forge, Dreadnought,
  Sovereign).
- Current-source stability: 39 matches, zero failures. The deliberately
  injected memory warning drains material, mesh, texture and audio caches.
  This is not proof of no memory leaks or physical-device battery/heat safety.
- Existing guards ran for each stage, and the test summary was independently
  checked again with `check_godot_log.sh ... tests`.

The sandbox run retained Godot's `get_system_ca_certificates` startup error.
Its logs are not clean `import`-mode logs; the existing runtime/test guards
passed without any guard changes or log filtering. The test log additionally
contains the intentionally induced failed save write and three failed router
loads. Their backtraces point to `_failed_write` in `test_save.gd` and
`FaultRouter` in `test_router_recovery.gd`, which explicitly inject these
failures and verify recovery. In contrast, all four clients in the separate
approved local macOS network run passed the stricter `import` guard.

- Full runner log: `/tmp/kras-scrap-final-full-gate-2026-10-08.log`.
- Per-stage evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.pnhdZC/`.

Fresh fetch still identified `origin/main` as
`062a40992b92958573e28e19d8c8c1840560797a`, not this development source.
No main integration, production mutation, new archive, upload or submission
was performed by this follow-up. Balance qualification, production qualification
and physical-device acceptance are still required before release.
