# Current-source canonical qualification - 10 October 2026

## Source and scope

- Checkout: `kras-qualified-current`; branch: `feature/kras-online-random-rotation`.
- Tested clean commit: `afcfc9cf5fce98c97d732de58b9a3f1c3ba1ed5e`.
- Selected gameplay source fingerprint:
  `adbbda6d74c6f6d6fb5f508ec50970e3123381f34a38f28329759d57b75ad1dd`.
- Imported runtime: `/tmp/kras-tank-pursuit-check`, without a Git checkout.
- Godot: `4.7.1-stable (official)`; headless fixed simulation rate: 60.
- Run: `local-canonical-2026-10-10-adbb`; seed offset: `76000000`.
- Start: `2026-10-10T08:09:56.777Z`; final aggregation:
  `2026-10-10T09:49:04.246Z`; runner exit: 0.

This campaign includes the Lab spawn correction, Sweeper opening grace and
Siege cue-history tests. It supersedes the older be795 campaign only as the
current canonical source snapshot, not as a deletion of historical warnings.
The fingerprint covers selected simulation source, not all assets, tests,
native exports or an App Store archive. No source was changed during execution.

## Completed evidence

| Check | Result |
| --- | --- |
| Canonical catalog coverage | 39 of 39 games |
| Natural baseline | 24 completed matches per game |
| Matched/mirrored difficulty comparison | 16 completed matches per game |
| Mutated and chaos smoke | 2 completed matches per game |
| Total | 1638 completed matches |
| Roster policy | Canonical `adjacent_rotation`, not supplementary balanced rosters |
| Official report aggregation | Complete; source and pairing verified |
| Runtime log guards | 78 stdout/engine logs passed the unchanged guard |
| Fresh full suite | 408254 assertions, 395.2 seconds, exit 0 |
| Full-suite stdout and engine guards | Both passed in `tests` mode |
| Fresh compile check | 450 scripts, exit 0; both log guards passed |
| Content audit with all 39 original rechecks | Exit 0; zero validation/evidence issues |
| Content classification | 34 NEEDS_POLISH, 5 NEEDS_BALANCE, 0 READY/REWORK/BROKEN |

The previous full suite had 408190 assertions. This fresh full execution includes
the additional 64 Siege cue-history assertions; it is not a relabeled older run.

## Remaining balance signals

| Game | Signal | Measured value |
| --- | --- | --- |
| tank_arena | Expert no better than Easy under the existing threshold | 0.50625 |
| goal_guard | Expert no better than Easy under the existing threshold | 0.519230769230769 |
| blast_ball | Expert no better than Easy under the existing threshold | 0.51875 |
| sweeper_storm | Expert no better than Easy under the existing threshold | 0.48125 |
| duel_pit | Spawn slot advantage | Slot bias 0.25; wins 12, 5, 1, 6 |

These are review signals from small canonical cohorts, not sufficient causal
proof of an unfair character, defective spawn or cheating AI. They remain open.
No thresholds, character statistics, physics, AI delays or random policies were
changed to suppress them. Earlier independent Sweeper/Siege samples remain
separate evidence and do not erase these canonical results.

Boss baseline outcomes: Forge 24 defeated / 0 survived; Colossus 17 / 7;
Dreadnought 24 / 0; Sovereign 24 / 0; unknown outcomes: zero. A completed
cooperative round does not mean the boss was always defeated.

## Logs and limitations

The macOS system-CA startup message remains present. The full suite also
deliberately exercises failed save writes and failed screen loading; their
ERROR lines are retained with test backtraces. Passing the project guard is not
a claim that the logs contain no ERROR messages.

The first Tank process was observed read-only while still running, not restarted
on an observation timeout. Its process sample is retained; a stripped native
stack and sampled footprint do not establish a leak, deadlock, phone memory use
or thermal behavior. All campaign processes reached terminal exit before the
next qualifying run started.

Raw evidence is outside Git in
`../qualification-adbb-canonical-2026-10-10/`: original campaign directories,
runner, execution metadata, summary, stdout, engine logs, full-suite and compile
logs, content audit and the read-only process sample. Temporary originals remain
under `/tmp/kras-adbb-canonical-2026-10-10/` and related named log files.

## External release gates remain closed

Public production health was checked in this turn and returned `ok=true`,
`authentication_ready=true`, `multiplayer_enabled=false`. This GET is not proof
of production database correctness, migrations, authenticated endpoints, native
release connectivity or a new Railway deployment.

- No merge or push to main; production backup/restore approval still gates it.
- No production migration, private database access or alternate deployment.
- No new local Xcode archive, upload, build processing or Apple submission.
- The older c0 network campaign does not qualify this current source automatically.
- Physical iPhone/iPad, real people/controllers, sustained FPS and thermal QA remain.
- Weekly Challenge remains unimplemented; later gated feature stages remain locked.
- READY/DONE and complete fulfillment of the product request are not claimed.

Next safe work: representative independent checks of the five balance signals
and current-source network qualification, followed by the externally authorized
device, production and release gates. Do not add features over an unqualified core.
