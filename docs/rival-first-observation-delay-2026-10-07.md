# First Rival Acquisition Qualification

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-rival-first-observation-delay.
Runtime/test commit: c8c869751051e0f523cd7cd35a014eb2b18327a5.
Parent: 27e0f5b64ba8a68c69aaa4496e027c44849fc0d6.

## Defect and Scope

The shared nearest, leader, edge-pressure and attack paths checked whether
a rival was visible but did not wait for that rival's first observed sample
to mature. Position/velocity history also fell back to its earliest sample
before the configured reaction deadline. Bots could immediately act on a
new rival despite the difficulty's reaction delay.

Shared target eligibility now requires an alive, currently observable rival
and a mature observation. Explicit zero-delay position targeting remains
available, but it does not manufacture recorded damage or last-seen memory.
Unknown positions/velocities retain the existing ZERO sentinel; callers are
gated before treating it as a valid target. Recorded hidden-target memory
remains separate from eligibility to attack a currently hidden rival.

The same guard is used in ball, bomber, climber, duo, generic, platform,
armed racing, relic, siege and zone candidate selection. Existing duellist,
collector and tag history contracts are preserved. The nearest/co-leader
seeded tie algorithm, physical movement, scoring, networking and save schema
are unchanged. Different acquired-target timing can change natural outcomes
and RNG consumption: older balance campaigns do not qualify this source.

## Regression Evidence

- Actual ring_rumble scenes, all four difficulties: first observation,
  just-before deadline, deadline, attack and round-reset checks.
- Before the initial fix: 25 passed, 84 failed.
- Final focused first-acquisition suite: 109 assertions passed.
- Final visible-target suite: 3997 assertions passed, including seeded ties,
  hidden/eliminated rivals and unsampled damage after a new round.
- Tie fixtures now record observations and advance the configured reaction
  delay. They retain the same seed/distribution and unique-target checks.
- git diff --check passed.

Focused logs:
/tmp/kras-rival-delay-red.log
/tmp/kras-rival-delay-final-focused.log
/tmp/kras-rival-delay-visibility-recheck.log

The initial full gate failed: 371115 passed, 1899 failed. This included old
tie fixtures without any observation and a genuine zero-delay recorded-
knowledge regression. Both were corrected; that failed run is retained at
/tmp/kras-rival-delay-full.log and kras-party-check.ouSBmP/tests.stdout.
The assertion-free-suite messages inside balance policy are deliberate
negative harness probes, not the reason the gate failed.

## Final Exact-Source Gate

The final full gate on c8c869751051e0f523cd7cd35a014eb2b18327a5 exited 0:

- 402 scripts compile; inventory: 495 resources, 22 autoloads, 27 routes,
  eight characters, zero issues.
- 373014 assertions passed in 309.3 seconds.
- Separate real three-lap race and all six boss regression probes passed.
- Stability: 39 matches, zero failures. Materials, meshes, textures and
  audio PCM caches drained to zero; memory after five seconds: 132987721
  bytes. This one-cycle probe does not establish long-term leak absence.
- All stages passed the existing strict Godot log guards. The stability
  memory warning is deliberately invoked by its test fixture.
- Server: 204 passed, zero failed/cancelled/skipped, 1783.859958 ms.
  All six KRAS_*_WORLD_FIXTURE variables reference this run's own
  saves-tests files, including armed, siege and the four bosses.

Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.yZFM7z
Logs: /tmp/kras-rival-delay-final-full.log,
/tmp/kras-rival-delay-server.log.
Runtime and tests remained unchanged during the gate. Documentation was
added separately. No current-source natural balance sweep, four-peer smoke
or physical device qualification was performed for this change.

Draft PR: https://github.com/shary17454/kras-pass/pull/157, based on the
preceding zone-observation branch. Attaching it to the task failed because
the task already exceeds 100 attachment identities; unrelated attachments
were not removed to work around that limit.

## Remaining Release Gates

This is not full completion or a main merge. Rendered hover-machine cues
still read private state without a delayed observation contract and need an
independent fix/test. All-game current-source natural balance qualification,
physical iPhone/iPad performance/gameplay/orientation, production backup and
protocol rollout approval/acceptance remain outstanding. The ASC browser
session most recently redirected to authResult=FAILED. No new signed local
Xcode 27 Archive, upload, processing or review submission is established by
this change. No P12 import, new certificate or certificate revocation.
