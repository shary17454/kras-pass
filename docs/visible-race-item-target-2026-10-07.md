# Visible race item target selection

Parent: 83f65131b64385cc359fa2dc0090e39a60b60123.
Branch: fix/kras-visible-race-item-target.
Worktree: /tmp/kras-visible-race-item-target.

## Reproduced defect

Rocket Rally's AI asked `rival_ahead(slot)` for the globally selected rival and
only afterward checked `can_target`. A hidden nearer-ranked racer therefore
masked a visible alternative. The leader fallback similarly selected the first
unfinished slot before considering visibility. All four difficulty tiers showed
both failures: the new regression produced 4049 passes and eight failures before
the runtime fix. Evidence: `/tmp/kras-race-visible-before.stdout` and `.log`.

## Fix and compatibility

`rival_ahead` accepts an optional internal eligibility Callable and applies it
before progress comparison and leader fallback. The AI passes its existing
`can_target` filter, which includes continuous visibility and reaction delay.
The final check is retained. No extra speed, damage, private position or item
knowledge was added, and no balance-review threshold was changed.

The ordinary `_launch_missile` path still calls the one-argument API, preserving
the game's existing automatic targeting for human-fired projectiles. No packet,
network protocol, save format, native bridge or UI contract was changed. The
deterministic race probe was updated to honor the optional predicate too.

The test uses the actual race controller, not only a synthetic selector. It
covers visible alternatives ahead and behind, all rivals hidden, finished rivals,
reacquisition delay, successful targeting after that delay, and unchanged
unfiltered selection, for all four difficulty tiers. 28 new assertions.

## Targeted qualification

Godot 4.7.1 official, headless, fixed simulation FPS 60, isolated saves.

| Check | Result | Stdout evidence |
| --- | --- | --- |
| Script compile | 415 scripts pass | /tmp/kras-race-visible-compile.stdout |
| ai_visibility | 4069 assertions pass | /tmp/kras-race-visible-after.stdout |
| race_rounds | 82 assertions pass | /tmp/kras-race-visible-rounds.stdout |
| armed_race_network | 176 assertions pass | /tmp/kras-race-visible-armed.stdout |
| race_conditions | 12 assertions pass | /tmp/kras-race-visible-conditions.stdout |

All five successful commands exited 0 and passed `tools/check_godot_log.sh`;
the test stages used its positive-completed-summary `tests` mode.
Total targeted assertions: 4339. The intentional pre-fix failures remain
preserved. The known macOS CA-access diagnostic is not concealed as a clean log.

## Not qualified by these checks

These targeted tests do not replace a full regression or current-source natural
balance campaign. A separate baseline Rocket Rally natural run was already in
progress on the unchanged parent worktree; it does NOT include this new fix.
Do not count its result as balance evidence for this branch. Human gameplay,
Internet play, actual-device FPS/heat/battery, production deployment and final
local Xcode 27 archive/upload/review remain separate release gates.
No main merge, archive, upload or App Store submission occurred here.
