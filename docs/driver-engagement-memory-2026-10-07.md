# Driver Backoff Engagement: Unaccepted Review Candidate

Runtime commit: `72fb3e8f94f6158ef88d6e0a6593d8ded832b681`.
Parent: `82017a7b7d914c8a9d059094b35a3628ce2aa379`.
Branch: `fix/kras-driver-engagement-memory`.

## Reproduced Behavior

The driver rerolled `priority_rival()` on every decision, including while
backing away to build a run-up. Changing rivals could reverse that maneuver's
destination. Its maneuver state also survived round reset/reconfiguration.

The regression test reproduces this at all four difficulty tiers with controlled
observed rival choices: before the runtime edit, 9 passed and 12 failed.
After the edit, 25 assertions pass (including four new reconfiguration checks).
It uses a real Scrap Karts context with an explicit observation double; it is
not a natural balance simulation or proof of human gameplay quality.

The candidate remembers only one rival ID during backoff. It retains the rival
only while the existing `can_target` perception/reaction gate allows it, uses
`predict`'s observed position, releases it when unavailable or when the maneuver
ends, and resets it on round start/configuration. No private position, stat buff,
new threshold or difficulty-profile change is introduced.

## Executed Checks

- Valid RED: `/tmp/kras-driver-engagement-before-valid.stdout`, exit 1,
  9 passed / 12 failed.
- GREEN: `/tmp/kras-driver-engagement-green.stdout`, 25 assertions, exit 0,
  strict test log guard passed.
- Compile: `/tmp/kras-driver-engagement-compile.stdout`, 416 scripts, exit 0,
  strict compile log guard passed.
- AI visibility: `/tmp/kras-driver-engagement-visibility.stdout`, 4069 assertions,
  exit 0 and strict log guard passed. This is the common perception regression,
  not every game/network/native requirement.

An earlier invocation omitted the isolated engine log path and crashed at
startup after failing to open `user://logs`; its trace is retained in
`/tmp/kras-driver-engagement-before.stdout`. An initial new-test parse error
(untyped inferred fighter) is retained in `kras-driver-engagement-red.stdout`.
Neither is counted as the behavioral RED or a passing check. Subsequent runs
use an explicit `/tmp` engine log and the corrected typed fixture.

## Natural Balance Is Still Failing

Each sample completed 24 natural baseline rounds, 16 mirrored difficulty rounds
and two short smoke checks. Both exited 0 and passed the runtime log guard;
severity-1 balance warnings still make these UNACCEPTED for balance.

| Offset | Parent Expert share | Candidate Expert share | Candidate character bias | Candidate slot bias | Warning |
| --- | --- | --- | --- | --- | --- |
| 1200000 | 0.5375 | 0.47826087 | 0.0833333 | 0.0416667 | expert bots no better than easy |
| 1500000 | 0.425 | 0.5125 | 0.0833333 | 0.0416667 | expert bots no better than easy |

The failing offset 1500000 improved but is still below the existing 0.52 gate.
Offset 1200000 regressed from a marginal pass to a failure. Fixing the reproducible
maneuver bug therefore does not justify accepting this as a complete balance
repair or merging it into a release. Preserve both offsets and warnings.

Raw reports: `driver-memory-scrap-natural-1200000.json` and
`driver-memory-scrap-natural-1500000.json`. Source fingerprint start/end:
`a7541c8ba509bf251c6082220258b53463ca3efde8ef0e05a26cb6518d98966f`.
The existing validator checked both sets' counts, eight mirrored character pairs,
baseline and smoke seeds, and retained `releaseReady=false`.

## Remaining Work

Investigate engagement, steering/reverse recovery and safe dash effectiveness
with actual perceived inputs and matched seeds. A full current-source regression,
broader balance and native/device/internet/production qualification remain
required. The previous parent's full gate is not a full gate for this candidate.
Do not merge either shared vehicle candidate until the retained difficulty
regressions are resolved. No main merge, production deployment, phone install,
new signed archive, upload or Apple submission occurred.
