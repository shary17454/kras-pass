# Colossus opening input qualification

## Scope

The network smoke driver's human input now starts an attack pulse immediately
when the visible attack plan first authorizes safe reach. Subsequent pulses keep
the existing simulation-time period and release interval. Leaving reach or a
non-playing phase clears readiness. This changes the test driver's strategy,
not player damage, boss health, exposure duration, time limit, or victory rules.
The cooperative boss policy from main remains in effect.

## Evidence

- Parent: `9fc95d579851a051efd0d338379a0ad55dbc5235`.
- Input change: `6dd76dd`; the actual network run used its exact two-file diff
  before that commit was created. No runtime files changed during the run.
- Focused clock tests: 14 assertions, exit 0, `/tmp/kras-opening-clock.log`.
- Compile check: 360 scripts, exit 0, `/tmp/kras-opening-compile.log`.
- `git diff --check` passed.
- Actual command: `node server/network-smoke.js --game=boss_colossus
  --tournament --humans=2 --seed=1872897823`, exit 0.
- Evidence directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Hmu5Xi`.
- Host and guest completed three matches with two Bots. Both reconnected.
  Scores `[470,330,0,0]`, final points `[15,9,6,4]`, cups `[3,0,0,0]`,
  champion slot 0, tournament complete. Guest received 5270 world snapshots.
- The existing strict per-round actual-boss-defeat gate remained enabled;
  this was not a timeout waiver or a forced victory fixture.
- Explicit log scan found no script errors, native ERROR lines, crash markers,
  leak warnings, or NETWORK_FAIL in the successful tests and both peer logs.
- The initial restricted test invocation could not write its default user log
  and crashed before the tests. The successful rerun used an isolated HOME,
  explicit log file, and approved local execution. That failure is not counted
  as a passing test or silently ignored.

## Limits and remaining work

One passing seed is not comprehensive stability or balance qualification.
The Bot slots scored zero in the final match: their boss tactics and difficulty
tiers still require investigation and independent balance campaigns. Loading
recorded a maximum host frame gap of 10559 ms; server loop maximum was 277 ms.
This run therefore does not establish a 60 FPS performance guarantee.
Historical failing logs and CI results remain valid evidence for their sources.
Full current-source CI, four-human online cases, independent seeds, physical
iPhone/iPad input and thermal/battery checks, and production Railway/client
coordination remain release gates. No archive, Apple upload, or review submission
was performed by this qualification.
