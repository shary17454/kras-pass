# Crate feedback replication qualification

## Source and scope

Runtime change: `1e3f497430d39d89a54cdd32fec558123c23f3ae`, branch
`fix/kras-crate-event-replication`, based on the Fawda qualification branch.
This is not a main merge, production deployment, or App Store release.

The old snapshot retained only the most recent break kind. A weapon break
followed by an ordinary break before the next snapshot lost the weapon's sound
and burst on replicas. Five fixed event lanes now retain each kind's sequence
and latest position. Repeated snapshots do not replay effects, and reconnect
baselines suppress historical effects. This is bounded feedback, not a complete
chronological event replay. Scoring, weapon probabilities, damage and authority
are unchanged.

## Compatibility gate

The crate world schema changes from five fields to six, with `break_events`
required by both Godot and the Node validator. Deploy server and client as a
coordinated protocol update; do not enable old clients against this server.
Production online play must remain disabled until release qualification passes.

## Executed focused tests

- Controlled mixed-event reproduction before the fix: 127 assertions passed,
  one failed (`/tmp/kras-crate-events-audio-before.log`). Audio was explicitly
  enabled; the earlier disabled-audio run is not reproduction evidence.
- Expanded Godot crate network suite: 160 assertions passed
  (`/tmp/kras-crate-events-final.log`). Includes malformed lane rejection,
  duplicate snapshots, reconnect suppression and mixed kinds.
- `node --test crate-world.test.js rooms.test.js`: 60 passed, zero skipped.
  Includes a real local WebSocket reconnect test. The initial sandbox-only
  loopback EPERM was rerun with authorized local socket access.
- `git diff --check`: passed before the runtime commit.
- Current diagnostic driver: all 335 scripts compile; Godot log guard passed
  (`/tmp/kras-crate-commit-compile.log`). Crate round lifecycle: 92 assertions
  passed with its log guard (`/tmp/kras-crate-rounds-current.log`).

## Actual four-peer tournament reproduction

Command: `node server/network-smoke.js --game=lab_crates --tournament --humans=4 --seed=1366831714`.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-q0Idmw`.
Runtime source was commit 1e3f497 with the diagnostic-only test driver change.
This is not the complete original CI seed sequence: the diagnostic server uses
the supplied seed for each of the three matches.

All four clients received matching scores for all three matches:
`[4,17,6,10]`, `[22,8,0,7]`, `[17,2,10,6]`. All four then failed the strict gate:
`weapon=true shot=false`. Final event counters were `[18,4,3,0,2]` for normal,
trap, shockwave, volley and ingot respectively. The host also recorded zero
volley events, so this reproduction does not indicate a dropped projectile
snapshot: the final match generated no volley. The earlier matches' final lane
counters were not retained by this diagnostic and must not be inferred.

Keep the projectile observation gate; do not call this a passing tournament.
This result narrows the next investigation to natural weapon coverage and
scripted player behavior. Server loop maximum was 2655 ms and the host frame
gap exceeded four seconds; this shared-machine headless run is not performance
or smoothness qualification.

## Remaining release gates

These focused tests do not establish the cause of the separate full tournament
failure. The previous Linux run 37200853991 used intended head e111e6f and a
synthetic PR merge checkout 82d452ba5a4430c38dabac8aa7c521e735e98131.
Its lab tournament failed the weapon/volley observation gate on host and guest;
its kart scenario also failed rescue observation. Keep both gates strict.
The current diagnostic driver reports weapon and projectile booleans separately
and includes the bounded event lanes when the lab gate fails.

Real Internet peers, physical-device performance, complete game QA, coordinated
Railway deployment, Distribution Archive validation and App Review remain
separate requirements. No focused test result substitutes for those gates.
