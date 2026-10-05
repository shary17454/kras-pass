# Color Safe Tile Arrival

Runtime source: `2334f5f0659d4ca63d2e8f795c2daa10fad080e7`.
Branch: `fix/kras-color-safe-tile-arrival`, based on main
`9d4580872c3585d8fd56ff0eca41cb3f595f45a1`.

## Change

The color bot previously requested full-speed movement even 0.15 units from
the center of its chosen safe tile. That makes narrow-tile arrival oscillate
between decisions. A controlled actual Color Stand scene reproduced the
problem: the extended reaction suite passed 12 assertions and failed the two
arrival assertions. That initial sandboxed run also logged a macOS system CA
access error; its log is not a clean engine qualification.

Arrival now uses horizontal distance, holds within 0.2 units, and reduces
approach input relative to the character's top speed and decision interval.
Far targets retain full input and the existing dash threshold. Character speed,
physics, difficulty parameters, floor generation, timing, elimination rules,
reaction deadlines and network payloads are unchanged. This is a bot steering
fix, not a forced minimum round duration or a movement advantage.

## Matched Natural Sample

Both reports used 24 baseline seeds starting at 1009001 in increments of 613,
the same eight character/seed mirrored difficulty pairs (16 matches), and
mutator/chaos seeds 1005501/1005502. Their seed and paired difficulty lists were
compared directly and match. Each report completed 42 natural matches; the
authored window remains 90 seconds. No round truncation was introduced.

| Metric | Main 9d45808 | Arrival 2334f5f |
| --- | --- | --- |
| Baseline mean duration | 4.5896 s | 27.3917 s |
| Baseline ties | 0 | 0 |
| Slot bias | 0.08333 | 0.04167 |
| Character bias | 0.08333 | 0.08333 |
| Expert place-share metric | 0.58125 | 0.71765 |

The Expert metric is placement share, not win rate or percentage improvement.
After-fix wins by slot: [6,7,6,5]. Both smoke variants passed and the tool
reported no flags. This small matched sample supports the arrival change; it
does not establish comprehensive balance or certify the game READY. The mean
remains slightly below the intended usual 30-second minimum party experience.

Reports: `/tmp/kras-color-natural-9d45808/report.json`,
`/tmp/kras-color-arrival-natural/report.json`. The latter runtime log passed
`tools/check_godot_log.sh`: `/tmp/kras-color-arrival-natural.log`.

## Verification

- Focused suite: 14 assertions passed, including hold, slowed approach, distant
  full input, sampled reaction deadlines, repeated-color calls and restart.
  Log: `/tmp/kras-color-arrival-fixed.log`.
- Full wrapper exited zero: 370 scripts compiled, 410 resources audited with
  zero issues, 359848 assertions passed in 191.7 seconds.
- Actual three-lap race and all six natural boss probes passed.
- Single-cycle stability: 39 matches, zero failures. Its cache release probe
  explicitly invokes the memory warning handler; this is not an OS-pressure
  event or proof of native iOS memory usage.
- Server: first sandbox run failed to bind localhost with EPERM. Outside the
  sandbox, 186 passed and six real-capture cases skipped. A subsequent run with
  all six current Godot capture files passed 192 tests, zero skips/failures.
  Final log: `/tmp/kras-color-arrival-server-captures.log`.

Full evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.kwKc6q/`.

## Release Boundary

This patch has not been merged to main, deployed, archived or submitted to
Apple. The earlier user-authorized main push selected 9d45808. Railway's live
observation showed deployment `2a3bda3c-4ceb-46d4-9730-d086c6c30340` BUILDING
from that commit; the previous 049e660 deployment remained SUCCESS. No duplicate
deploy or production configuration change was issued.

All-agent perception, representative balance, original visual/content polish,
physical iPhone/iPad orientation/touch/gamepad, sustained FPS/energy/thermal,
four-device Internet/reconnect, replay/persistence acceptance and an exact-source
Distribution release remain required. The complete product goal is unfinished.
