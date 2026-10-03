# Sovereign target eligibility (2026-10-03)

Starting source: `dd5c024ff9105f786d83ebce9688d771d019d037` on
`feature/kras-online-release`.

## Reproduction

Actual separate-process network logs from the previous qualification showed
collapse warnings outside the arena and at a respawn-wait height of -500.
`ctx.is_alive` denotes a slot still participating in the match; it does not
prove its Fighter is active, visible or standing over reachable arena ground.
`Arena.is_inside` alone checks horizontal bounds, not elevation.

`test_sovereign_targets.gd` creates a real match and controls Fighter states:
an active jumping fighter, a below-floor slot, a hidden fighter and a dead
fighter. It exercises real pursuit/collapse selection, all-ineligible states,
an eliminated match slot and a translated/elevated arena.

Before the fix: 19 assertions passed and 12 failed in
`/tmp/kras-sovereign-targets-before.log`. It selected hidden slot two and
created warnings at -500 and at a jumping fighter's airborne height.

## Fix

- Both closest-target selection and targeted collapse warnings use one
  private eligibility predicate: match-alive, valid Fighter, Fighter-alive,
  visible, finite position, no more than 0.5 below the arena plane, and inside
  actual arena ground with the established 0.5 edge margin.
- Valid airborne players are still eligible. Their pursuit/collapse warnings
  use their horizontal position projected onto the actual arena floor height.
- Pursuit does not move or schedule a warning without an eligible target.
- The five authored radial collapse hazards still run even if no Fighter
  is currently eligible. Attack powers, radii, periods, recovery, boss health,
  phases, scoring and match duration are unchanged.

## Evidence

- `/tmp/kras-sovereign-targets-after.log`: 25 assertions passed. The count is
  lower than the failed run because only six valid warning rows, not nine
  erroneous rows, are inspected; explicit warning-count checks remain.
- `/tmp/kras-sovereign-targets-collapse.log`: all 15 final-phase/core-strike,
  lethal-finish and next-round assertions passed.
- `/tmp/kras-sovereign-targets-network.log`: all 141 replication, bounded
  events, sound freshness, next-round and replacement-baseline assertions
  passed. This is a controlled host/guest fixture, not an Internet test.

The previous CI run 37069444943 completed successfully with 37 jobs on
`5d89d19450c775d24e849496605b82760c406c5c`. That result does not certify
this fix or the later Dreadnought/Sovereign matrix additions. A fresh pinned
run is required after these changes are committed and pushed.

- `/tmp/kras-sovereign-targets-ai.log`: the real authored four-Expert-Bot
  match, seed 9614, defeated Sovereign at zero health with contribution
  scores `[360,300,540,300]`. This is one seed, not a balance certification.

The actual four-client regression on this fix passed, seed 9614, two internal
rounds with real damage, volleys, shields, orb returns and boss defeats.
All four distinct identities agreed on scores `[930,870,270,960]`. Host
result-loss recovery and guest reconnect passed. The guests received 3,718,
3,737 and 3,737 world snapshots. Evidence:
`/tmp/kras-sovereign-targets-four.log` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-4fWdC7`.
The driver rejects any sampled Sovereign warning whose height differs from
the arena floor by more than 0.01, rather than checking only final scores
after transient warnings have disappeared. It reported no such failure.

Server event-loop max was 5,667 ms and host maximum frame gap was 13,909 ms.
These are serious unresolved local scheduling/preparation findings. The
functional pass does not certify acceptable latency, smoothness or FPS.

Preparation stalls, physical-device performance,
Colossus network replication, production Railway sync and Apple release
gates remain open. No merge, deploy, Archive or App Review submission is
claimed here.
