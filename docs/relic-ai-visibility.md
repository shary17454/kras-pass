# Relic AI visibility qualification

This follow-up starts from main `6b1d9e9bbae50d15245b32ef1467eeed74cc2da9`.
Relic Hold now exposes the actual loose collectible rather than asking bots to
target `relic_position()`, whose fallback can identify the arena centre without
a visible prize. The brain skips hidden, inherited-hidden and queued prizes,
and does not pursue a hidden carrier. Public carrier identity and held scoring
are unchanged; visible carrier pursuit still uses the existing delayed fighter
history. Missing visible targets cause retreat rather than fabricated pursuit.

Terminal checks on this patch:

- `/tmp/kras-relic-visibility-final.log`: 108 assertions passed, exit zero.
- `/tmp/kras-relic-round.log`: 47 assertions passed, exit zero, including pickup,
  cleanup, reset, authoritative carrier state and network replica presentation.
- `/tmp/kras-relic-compile.log`: all 323 scripts compile, exit zero.
- `git diff --check`: passed.

The engine logs retain the macOS system certificate retrieval warning. These
focused checks do not prove wall/camera occlusion, all object reaction delays,
balance, physical-device performance or Apple release readiness. Full regression
has not been rerun after this relic patch.

Separate qualification of the preceding main source:

- Runtime source `0e2610e553d91a69ebf6005b19f0554052799e35` passed 21,162
  assertions in 1,607.6 seconds (`/tmp/kras-ball-delay-regression.log`).
- All six world captures from that run were supplied to the Node server tests.
  `/tmp/kras-ball-delay-server.tap`: 120 passed, zero failures or skipped tests.
  Local ephemeral socket permission was granted for this run.

No App Store archive, upload, processing or review submission is claimed here.
