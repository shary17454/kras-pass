# Bomber Observed Cues

## Scope

Runtime parent: `57e0d6d9c8977dcf5ae183f0cbc3cf2c3acd91da`.
Branch: `fix/kras-bomber-observed-cues`.

Fawda's bot formerly read live positions and the exact private fuse on every
decision. Adding reaction time to its panic threshold was not delayed perception.
The bot now samples rendered cues at the shared history cadence, retains at most
32 samples, and acts on the newest sample at or before its reaction deadline.
Bomb identities prevent a new bomb from inheriting an old observation.
Hidden, queued, and removed bombs cannot become targets from retained history.
Round restart clears the observations.

The controller exposes a half-second estimate derived from the rendered wick,
not its private countdown. A missing or hidden wick is unknown, not an immediate
explosion. This changes bot decisions, not bomb physics, drops, damage, scoring,
player movement bonuses, or network replication.

## Tests Executed

- AI visibility suite: 2034 assertions passed, runtime log guard passed.
  `/tmp/kras-bomber-cues-tests.log`.
- Fawda network presentation suite: 130 assertions passed, log guard passed.
  `/tmp/kras-bomber-replica-tests.log`.
- Natural-duration sample exited zero and passed the runtime log guard.
  `/tmp/kras-bomber-natural-isolated.log` and
  `/tmp/kras-bomber-natural-isolated/report.json`.
- Two baseline matches, 16 completed matched-seed/character difficulty matches,
  and two mutator/chaos matches completed. Natural round window was 95 seconds;
  elimination could finish sooner. Baseline mean was 33.25 seconds.
- Seed offset: 200000. Baseline seeds: 209001, 209614.
- Expert share: 0.49375. The report retains the severity-one warning
  `expert bots no better than easy`. No threshold was relaxed to hide it.
- Two baseline victories by Sakhra are not adequate evidence of character
  balance; the small sample cannot qualify all eight characters.
- `git diff --check` passed.

## Test Isolation Note

An earlier simulation invocation lacked an explicit isolated save directory and
was deliberately interrupted, not counted as passing. The balance tool writes
local desktop settings for control hints and replay capture. The replacement
used `--test-data-dir=/tmp/kras-bomber-natural-save`; this is the completed sample
listed above. No existing save was deleted or restored from a guessed state.

## Remaining Gates

This is not full camera-frustum or wall-occlusion perception. Existing visibility
guards still have those limits. The difficulty warning requires larger paired
samples and review, not hidden bot speed or damage bonuses. All-game regression,
physical-device performance/energy/controller testing, and production Online
qualification remain incomplete. No main merge, signed distribution archive,
App Store upload, processing, or review submission is asserted here.
