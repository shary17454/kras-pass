# Sweeper Arrival Relative to Own Movement

Base: `07a416258a8c3d9532b1a5c998dccf88e697e4e7` (PR 150).
Runtime: `1ff5e5624685bf0726adf8f097d38cb3c207b3db`.
Branch: `fix/kras-sweeper-relative-arrival`. No main merge or release.

## Correction and Limits

Dodger estimated angular arrival as if its own fighter were stationary.
The estimate now subtracts its own instantaneous tangential angular motion
from the delayed, visibly sampled blade motion. Closing direction and ETA
use that relative rate; equal rates are not a closing encounter at that
instant. This is a short-horizon local angular-rate approximation, not an
exact future collision solver for curved/accelerating fighter trajectories.

Only the fighter's own horizontal velocity is added. Blade visibility,
camera/occlusion checks, delayed history, reaction time, sampling and
prediction remain unchanged. Private hazard schedule/speed, rival hidden
positions and future inputs are not read. No stat, hazard power, round
duration, balance threshold, weapon or network rule changed.

## Tests

Identical final arrival fixture on the original implementation:
147 passed, 18 failed. Corrected implementation: 165 passed. It checks
both rotation directions at three angles, stationary/toward/away motion,
equal angular rates and hidden-arm exclusion.

Additional completed suites:
- Actual camera/occlusion/reappearance visibility: 19 passed.
- Own jump timing across character/gravity/jump modifiers: 65 passed.
- Shared AI visibility: 3962 passed.
- Actual sweeper hitbox/capsule contacts: 25 passed.
- Sweeper network presentation contract: 26 passed.
- Signed physical impact direction/power: 31 passed.
- All 398 scripts compile; strict log guards and git diff --check pass.

Logs: `/tmp/kras-sweeper-arrival-{red,final,camera,jump,visibility,hitbox,
network,impact,compile}.log`. An earlier `--suite=sweeper` invocation
selected no suites and failed; the runner uses exact suite IDs. It is not
counted as gameplay coverage. The three exact sweeper suites above completed.

## Natural Match Evidence

Every report contains 24 baseline matches, 16 matched-character/seed
difficulty matches and two mutator/chaos matches. All finished naturally.
Comparison checks confirm identical baseline seeds/difficulty assignments
between each baseline and candidate. No shortened clocks or forced winner.

| Offset | Source | Expert score share | Slot bias | Character bias | Mean duration | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 900000 | baseline | .496894 | .083333 | .166667 | 26.1903 s | Expert no better than Easy |
| 900000 | candidate | .503106 | .125000 | .083333 | 25.6597 s | Expert no better than Easy |
| 300000 | baseline | .518750 | .083333 | .250000 | 29.1361 s | Character advantage; Expert no better than Easy |
| 300000 | candidate | .537500 | .083333 | .250000 | 28.0597 s | Character advantage |

The modest score-share improvement in both samples is not proof of broad
statistical superiority. Offset 900000 still fails the Expert review; the
independent sample retains character advantage. This is NOT a complete
balance fix or READY qualification.

Reports: `sweeper-relative-{baseline,candidate}-{900000,300000}.json`.
Baseline runtime fingerprint (start=end):
`cc80fc3c03e82587d7454edc8a401cfbda70d9133c4c7f9f3f10462efb06beaf`.
Candidate runtime fingerprint (start=end):
`eaa28fed85b636491087ea1b094388e5e024c9e03750c360404919668fc0d418`.
Candidate runs used this exact runtime before its commit. Between runs, the
runtime file was temporarily restored with apply_patch to measure the exact
independent baseline, verified diff-empty, then the candidate was restored.
No runtime edit occurred during any measured run.

## Remaining Gates

The full 371649-assertion gate belongs to the parent HUD source, not this
changed AI runtime. A fresh full regression and actual multi-process peer
acceptance remain. The 26 network assertions are schema/presentation tests,
not four real peers or Internet play. The all-39 campaign 37549144464 retains
its immutable older HUD commit and was not cancelled/replaced.

All-game balance/polish/perception, physical iPhone/iPad performance and
gameplay, approved source integration, production backup/restore/migration
and online/auth acceptance, frozen Version/Build, local Xcode 27 signing,
upload, processing and separate App Review submission remain incomplete.
No production change, certificate import/change or Xcode Cloud use.
