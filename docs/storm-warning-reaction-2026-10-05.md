# Storm Public Warning Reaction

Runtime/test source: `e8675acd0540297e870b2a255ab53dc655997ad4`.
Parent: `450f5157225cfd0fb0206a6ef67349d5f5b57958` (incoming defense PR 92).
Branch: `fix/kras-storm-warning-reaction`. This is a stacked correction;
no automatic main merge, production setting change or Apple submission occurred.

## Defect and Correction

Storm Heart exposed its global HUD/audio warning immediately to the keeper's
decision, ignoring the configured difficulty's reaction time. The new regression
on the old runtime completed with 21 passing and sixteen failing assertions:
immediate reaction, premature reaction, next-warning credit and restart credit
failed for every difficulty. Log: `/tmp/kras-storm-warning-red.log`.

The keeper now records the first decision-time observation of the public warning
and waits its existing reaction interval before acting. One bounded timestamp
is reset when the cue expires, on round restart, on reconfiguration or when the
controller is unavailable. Delays use simulation time, not wall time. Observing
only at decision cadence can add a decision interval to the earliest response;
it cannot remove the configured reaction delay.

The warning is public to all players through the existing global HUD/audio.
No private future volley bearing, velocity bonus, accuracy bonus or hidden
difficulty override was added. Missing/expired cues cannot drive later home
positioning. The prior incoming-ball defense remains higher priority after the
warning is perceived, and normal interception continues while it is delayed.

## Current-Source Focused Checks

- Warning reaction: 49 assertions, exit zero; all four profile reaction times,
  threshold boundaries, expiry, restart, repeated and short-lived warnings.
- Incoming defense: 25 assertions, exit zero; actual oblique shield contact on
  all four sides, delayed samples rather than live velocity, and home fallback.
- Storm network presentation: 178 assertions, exit zero.
- All 379 scripts compile, exit zero.
- Completed engine log guards and `git diff --check` passed.

Logs use `/tmp/kras-storm-warning-{green,defense,network,compile}.log`.
The incoming test fixture now establishes warning observation and advances its
profile reaction interval before asserting perceived-warning behavior; its
shield interception and fallback assertions were not removed or loosened.

## Natural-Round Balance Evidence

Fresh before and after samples used identical seed offset 300000, eight baseline
matches, sixteen mirrored difficulty comparisons across eight characters, and
two mutator/chaos checks per sample. All 26 matches completed in each sample.

Expert placement share decreased from 0.533653846 to 0.524038462 after removing
the instantaneous warning advantage. Both retained no flags under the existing
thresholds. The independent seed offset 600000 sample completed another 26
matches, share 0.524038462, no flags, both smoke checks successful.
Reports: `/tmp/kras-storm-warning-{before,after,independent}-report/report.json`.
Each engine process exited zero and passed its runtime log guard.

The small advantage is close to the 0.52 review threshold: these samples do not
prove robust difficulty separation, statistical balance or all-map fairness.
No threshold, character stat, round duration or win rule was changed to regain
an apparent advantage. Other balance candidates remain open.

## Actual Four-Peer Transport

Command: `GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js
--game=storm_heart --humans=4 --seed=438683058`, local WebSocket service.
All four actual Godot processes completed with exit zero, moved and agreed on
scores `[11,17,18,14]`. Host and one client restored connection/identity; clients
observed 1107/1107/1083 world snapshots. The retained turbine network assertions
cover actual warnings, volleys and replicated ball presentation.

Log: `/tmp/kras-storm-warning-four-peer.log`.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-h75yhK`.
These are automated human-input peers, not four real people or a bot difficulty
comparison. Server loop maximum 266 ms disqualifies any smooth-latency claim.
No production multiplayer enablement or real Internet acceptance is inferred.

## Remaining Qualification

The previous full 360404-assertion, 39-stability-match and 192-server-test checks
apply to parent runtime `3b601bd`, not this new warning correction. They must not
be relabelled as a full current-source pass. Full integrated/hosted quality,
broader AI perception and balance, original-content polish, physical iPhone/iPad
FPS/RAM/thermal/battery, real Internet multiplayer, release-source production
sync and exact-source Distribution archive/upload/processing/review remain open.
This change is progress toward fair AI, not completion of the full objective.
