# Scrap Karts contact batches and starting headings

Starting commit: `3dd51dfec7ee97f7cfc179e6c7b0408c1ae9ae30`, branch
`feature/kras-online-random-rotation`, origin `shary17454/kras-pass`.

## Reproduction and behavior

The old pair loop eliminated riders before processing the remaining contacts
from the same physics frame. In an equilateral three-rider collision, only one
of three contacts resolved; permuting the roster changed the survivor. The
regression against that implementation failed 49 assertions. Mutual lethal
head-on collisions also assigned different survival ranks by loop order.

Contacts now collect their damage/impulses before elimination. Simultaneous
wrecks share their survival rank; the strongest total damage contribution
receives knockout credit, with equally strongest contributors co-credited.
An equal nonlethal push has no arbitrary last-hit owner. Round resets clear
these ranks. No collision threshold, damage budget, cooldown, physics speed,
or network authority rule was weakened.

An older test expected a second simultaneous contact to disappear when the
first wrecked its attacker. It was updated to distinguish a contact batch
that began alive from a later collision involving an already wrecked rider.
The latter remains rejected; the direct damage entry also rejects eliminated
attackers. This is a deliberate simultaneous-resolution rule change, not a
claim that the old full-suite failure never occurred: that run exited 1 with
395485 passed and 3 failed assertions.

Starting heading was another independently reproduced defect. All DRIVE
motors initialized to the same world heading despite four ring spawn points;
facing and motor heading also disagreed on the first throttle tick. The new
start/reset regression failed 14 assertions before the correction. Scrap
round starts now call the existing `face_direction` toward the arena center,
synchronizing presentation and steering without modifying other vehicles.

## Evidence

Godot 4.7.1; fixed FPS 60 for headless unit/integration/simulation tests;
isolated storage, explicit logs, strict log guards (not engine exit alone).
Runtime fingerprint:
`d8df26545720bc3696c26da5a16f5edb18912d97676252a1e0fa3fe705f5ac38`.

- Contact lifetime suite: 46 assertions, exit 0.
- Scrap presentation/contact/start-heading suite: 273 assertions, exit 0.
- Compilation: 440 scripts, exit 0.
- Natural baseline seed offset 5200000: 24 baseline + 16 paired difficulty
  + 2 mutator/chaos matches; flags `[]`, seat win credits `[6,7,7,5]`, seat
  bias 0.03, Expert finishing-place edge 0.521739. Before the heading change,
  the same campaign had seat credits `[13,4,3,5]`, bias 0.27 and warnings.
- Independent seed offset 5400000: 42 matches, flags `[]`, seat bias
  0.208333, Expert edge 0.534161. Both reports retain identical start/end
  fingerprints. These samples do not prove universal balance.
- Four actual engine peers: PASS, scores `[14,22,16,12]` identical across
  host/guests, host and guest reconnect, 1178 world snapshots on uninterrupted
  guests; server loop maximum 30 ms on this local test, not production/iOS QA.
- Three-round four-peer tournament: PASS, identical round scores and final
  points `[9,6,4,15]`, champion `[3]`, host/guest reconnect. All four peer logs
  passed the runtime guard. Server loop maximum 79 ms while local tests ran
  concurrently; this is not a production performance acceptance result.
- Full regression: 395507 assertions, 387.0 seconds, exit 0; strict test log
  guard passed. This includes the revised contact lifetime contract, all
  existing suites and the new heading/contact regressions.

Raw logs and reports are retained in
`../qualification-scrap-contact-fairness-2026-10-09/`.
Sandbox system CA warnings are preserved, not described as zero warnings.

## Remaining release gates

Current-source all-game balance/network qualification, actual iPhone/iPad
controls/performance/energy QA, unfinished product requirements, production
backup/deployment/native connectivity, exact-source Xcode 27 Distribution
archive, upload processing and review submission remain separate gates.
No main merge, Railway deployment, Apple upload, submission, P12 import or
certificate replacement was performed for this correction.
