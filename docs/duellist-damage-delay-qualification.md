# Duellist Damage Delay Qualification

## Defect and fix

Duellist target ranking and finisher decisions read a rival's current
`damage_percent`, even when position prediction used delayed observations.
The value is public on the Duel HUD, but immediate access bypassed the configured
reaction time and could select a newly damaged rival before the bot should react.

Three regression assertions failed before the production fix: delayed target
selection, future unsampled damage, and stale information after a round reset.
The baseline log recorded 2008 passed and three failed assertions.

`AIBrain` now stores bounded whole-percent HUD damage alongside the existing
20 Hz position/velocity history. Only the duellist enables damage sampling.
The decision reads the same delayed sample, rejects hidden or not-yet-observed
rivals, and clears damage history between rounds. Storage remains capped at
32 samples, not an unbounded event list.

The fighter's own damage remains immediately available, just like its own HUD.
This does not grant the AI speed, damage, movement or spawn bonuses. No character
stats, balance thresholds or match outcome criteria were changed.

## Fixture integrity

The visibility suite's old Duo fixture cleared every modifier key instead of
resetting the shield it was testing. A later live HUD update then encountered a
missing `frozen` key. The fixture now resets only shield and asserts that the
required modifier schema remains intact.

An intermediate run reported 2011 passed assertions but contained SCRIPT ERRORs;
it is rejected as qualification. An attempted `--suite=ai` command selected no
suite and failed. The real selection is `--suite=ai_visibility`, not a prefix
match. Neither failed command is represented as a successful test.

## Verified results

On Godot 4.7.1, local macOS, isolated test data:

| Check | Result | Log |
| --- | --- | --- |
| AI visibility including damage delay | 2022 assertions passed | `/tmp/kras-duellist-damage-clean.log` |
| Goal Guard compatibility | 144 assertions passed | `/tmp/kras-duellist-goal.log` |
| Duel network presentation contracts | 39 assertions passed | `/tmp/kras-duellist-network.log` |
| Compile check | 327 scripts compiled | `/tmp/kras-duellist-compile.log` |
| Source comparison | 355 inputs, zero differences | actual Git-tracked game code/data/resource comparison |
| `git diff --check` | passed | current working tree |

`tools/check_godot_log.sh` passed for all four accepted logs; the test mode also
requires a positive completed assertion summary. Compared source inputs were
gd/tscn/tres/json files under src, tests, data, scenes, resources and addons, plus
project.godot. This is not a claim that the warm checkout's Git HEAD or every
binary asset equals the source tree.

Covered regressions: configured reaction time, future unsampled damage, hidden
rival rejection, initial/round-reset unknown state, integer HUD values, invalid
slots, ring-buffer wrap and bounded storage.

## Balance and release limits

Before this new fix, the independent 99d1b00 campaign's available 35 games
qualified 1470 matches. Nine games still raised balance warnings: blast_ball,
bumper_bowl, duel_pit, gem_grab, magnet_court, scrap_karts, sky_court,
sweeper_storm and tag_hunt. Four game artifacts were not yet downloaded at the
time of that partial summary. These old-source results cannot qualify this
new duellist revision's balance.

No full-current-source balance campaign or current signed iOS archive is proved
by the focused tests above. No physical Online peers, controller hardware,
portrait/landscape, battery or thermal claim is made. Production multiplayer
remains disabled. This work is not an App Store submission or Apple approval.
