# Tank AI firing distance and recorded finals

## Reproduction and change

Starting source: `8623159e3b48d051851ce0f8b5ca058cc8b9d694`.
GitHub run `37873023873` passed the remote-only final but failed the recorded
two-human final (seed `15775892`, contenders `[0,2]`): shot/inventory present,
no armor-hit evidence, scores `[500,100,500,200]`.
The same failure reproduced locally in `kras-network-smoke-SAaaC9`, exit 1.

Tank AI always drove toward its delayed rival, including inside the muzzle's
clearance, and a visible ammo crate could override a close clear engagement.
The new steering regression failed nine assertions against that implementation.

`src/ai/brains/tank_brain.gd` now holds a clear firing lane within 12 units,
backs up within 3 units, and prioritizes that close engagement over optional
ammo. Steering still goes through the existing DRIVE inputs. Blocked/distant
rivals retain normal route/approach behavior. All four difficulty tiers follow
the same distance rules. Perception, reaction delay, aim error, speed, damage,
physics, shell types, final duration and network authority were not relaxed.
No test pilot or hit-evidence assertion was changed for this correction.

## Current evidence

Runtime fingerprint:
`80d45a8e41fe00f55372654476bf8082bdcbb68c1422d009f68391a18e7f0f8d`.

Commands use Godot 4.7.1, isolated test data, explicit logs, and fixed FPS 60
for local unit/integration/simulation runs. Network tests use real Godot
processes and a local WebSocket service without production credentials.

- Focused `tank_network`: 184 assertions, exit 0; log guard passed.
- Focused `tank_crate_perception`: 93 assertions, exit 0; log guard passed.
- Full `tests/test_runner.tscn`: 395352 assertions, 261.7 seconds, exit 0;
  strict test log guard passed.
- `tests/compile_check.tscn`: 440 scripts compile, exit 0; log guard passed.
- Natural `balance_sim.tscn --runs=24 --only=tank_arena --seed-offset=5200000`:
  24/24 baseline, 16/16 matched seed/character difficulty, two mutator/chaos
  cases complete; 42 matches total. Start/end fingerprints match.
  Flags `[]`, baseline tie rate 0, slot bias 0.166667, character bias 0.125,
  Expert finishing-place edge 0.5875. This is one sample, not universal balance.
- Recorded two-human final `Lpr966`: PASS, scores `[406,100,300,200]`, champion
  `[0]`, host/client reconnect and identical results; both raw logs guarded.
- Three-contender final `ZZYY8j`: PASS, genuine first-final tie followed by
  a second final, scores `[300,100,420,200]`, champion `[2]`; all four raw logs
  guarded. A legal tied attempt is preserved, not silently counted as a win.
- Remote-only final `Y5nlev`: PASS, scores `[100,431,200,300]`, champion `[1]`,
  host as spectator, remote contenders and reconnect; all four logs guarded.
- Content audit: 0 structural errors, READY 0, NEEDS_POLISH 1,
  NEEDS_BALANCE 38. Tank evidence is current; other games' old fingerprints
  are not relabeled as current. Device/playability sign-off remains absent.
- `git diff --check`: passed.

Raw evidence is retained outside the source checkout at
`../qualification-tank-firing-range-2026-10-09/`, including the failed
pre-fix reproduction, red/green tests, complete regression, balance report,
content audit and network peer logs.

## Remaining gates

The original CI run remains failed. Follow-up run
[37875342110](https://github.com/shary17454/kras-pass/actions/runs/37875342110)
completed successfully on `3dd51dfec7ee97f7cfc179e6c7b0408c1ae9ae30`.
Its original downloaded artifacts confirm ordinary two/four-peer matches,
a multi-round tournament, recorded two-human final, three-contender final,
and remote-only final PASS. All 22 raw peer logs passed the runtime log guard.
Artifacts are retained at `/tmp/kras-tank-3dd-ci-completed/`.
This does not qualify all 39 games. Storm/base-siege balance warnings remain
open; the subsequent Scrap contact/heading correction has separate evidence
in [its report](scrap-contact-fairness-2026-10-09.md).
Physical iPhone/iPad gameplay, sustained frame-time/thermal/battery QA,
production deployment/database/connection gates, and the full requirements
audit remain unfinished.

The previous local Xcode 27 archive was built from `ee8470d`, not this runtime
correction. A new source-attested archive is required before any upload.
No main merge, Railway deployment, Apple upload or review submission is
established by this report. No P12 import, password request or certificate
replacement is involved.
