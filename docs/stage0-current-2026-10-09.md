# Current Source Inventory And Release Gates

Verified source: `e3ac6079d9ffb2515deb6da3f522f9e14d37e338` on
`feature/kras-online-random-rotation`, origin `shary17454/kras-pass`.
This is a current evidence update, not acceptance of all product requirements.

## Inventory

Godot 4.7.1: 540 inspected resources, 22 instantiated autoloads, 27 screen
routes, 8 characters, 39 minigames, 34 arenas, zero inventory issues. Registry
validation runs in Arabic and English. Character stat budgets are checked.
The boot scene can instantiate; route resources exist. This does not prove
that every route has been interactively exercised on iOS.

Compilation: all 438 scripts passed. Full regression: 394134 assertions,
203.0 seconds, exit 0. The routed tournament fixture completed 18 natural
matches, including the limited sudden-death chain and explicit shared cup.
See [tournament evidence](routed-tournament-flow-2026-10-09.md).

Runtime fingerprint:
`71b5a52a33d4be33e306e93acdc777fdf3b7de41c82e8e463cbc88bd7901ed7c`.
Inventory fingerprint (different scope, including tests/resources):
`777a818985c36850138c8be724ce2e53fd96c5627eba2894c54f1eb0c726a6c8`.

## Current Per-Game Report

The content audit imported no qualifying balance report for this fingerprint.
All games have zero structural validation errors, but remain NEEDS_BALANCE.
This status means missing current evidence, not demonstrated broken gameplay.
No game is marked READY from compilation, a nonblank screenshot or an old
balance campaign. Raw content-audit.json includes each game's controller,
inheritance, AI, camera, input scheme, maps, duration and evidence gaps.

| Game | Status | Structural Errors |
|---|---|---|
| tank_arena | NEEDS_BALANCE | 0 |
| ring_rumble | NEEDS_BALANCE | 0 |
| crumble_court | NEEDS_BALANCE | 0 |
| bumper_bowl | NEEDS_BALANCE | 0 |
| fawda | NEEDS_BALANCE | 0 |
| goal_guard | NEEDS_BALANCE | 0 |
| magnet_court | NEEDS_BALANCE | 0 |
| storm_heart | NEEDS_BALANCE | 0 |
| sky_court | NEEDS_BALANCE | 0 |
| blast_ball | NEEDS_BALANCE | 0 |
| scrap_karts | NEEDS_BALANCE | 0 |
| turret_duel | NEEDS_BALANCE | 0 |
| gem_grab | NEEDS_BALANCE | 0 |
| star_rush | NEEDS_BALANCE | 0 |
| paint_grid | NEEDS_BALANCE | 0 |
| mnatiq | NEEDS_BALANCE | 0 |
| mukharrib | NEEDS_BALANCE | 0 |
| zone_hold | NEEDS_BALANCE | 0 |
| crate_smash | NEEDS_BALANCE | 0 |
| lab_crates | NEEDS_BALANCE | 0 |
| crate_relay | NEEDS_BALANCE | 0 |
| hurdle_dash | NEEDS_BALANCE | 0 |
| kart_sprint | NEEDS_BALANCE | 0 |
| color_stand | NEEDS_BALANCE | 0 |
| symbol_echo | NEEDS_BALANCE | 0 |
| quick_draw | NEEDS_BALANCE | 0 |
| rising_tide | NEEDS_BALANCE | 0 |
| sweeper_storm | NEEDS_BALANCE | 0 |
| duel_pit | NEEDS_BALANCE | 0 |
| boss_forge | NEEDS_BALANCE | 0 |
| boss_colossus | NEEDS_BALANCE | 0 |
| boss_dreadnought | NEEDS_BALANCE | 0 |
| boss_sovereign | NEEDS_BALANCE | 0 |
| sabaq_sawarikh | NEEDS_BALANCE | 0 |
| relic_hold | NEEDS_BALANCE | 0 |
| tag_hunt | NEEDS_BALANCE | 0 |
| base_siege | NEEDS_BALANCE | 0 |
| drift_floes | NEEDS_BALANCE | 0 |
| duo_clash | NEEDS_BALANCE | 0 |

## Unfinished Gates

- The original complete product scope remains open. Weekly challenge is absent;
  neither this inventory nor the routed test implements it.
- Physical iPhone/iPad multiplayer, controller acceptance and sustained thermal,
  energy and frame-time measurements are not established by desktop tests.
- Current-fingerprint all-game balance and network qualification remain open.
  Runs 37859085528 and 37859962068 still test c1ee03c, not this source.
- Production database backup/restore authorization, Railway deployment and
  actual production API/native authentication verification remain separate.
- No exact-current-source Distribution archive, upload or submission happened.
  The existing 1.1.11 (110) archive belongs to older source 3e83904.
- Stage transitions still require their documented tests, QA and merge. This
  report does not mark any new stage DONE or silently waive device release QA.

## Evidence And CI Synchronization

Raw inventory.json, content-audit.json and the corresponding Godot logs are in
`../qualification-routed-tournament-2026-10-09/`. Both audit processes exited
0 and passed tools/check_godot_log.sh individually. Documented sandbox CA
warnings remain in the logs; they are not erased or described as zero warnings.

The feature branch push trigger is disabled (push accepts main only), and the
branch has no open PR at verification time. A feature-branch push therefore
does not cancel the currently running workflow_dispatch campaigns. They retain
their captured c1ee03c source. A new core_only dispatch uses a separate
concurrency suffix and can validate the new source without cancelling them.
No force push, main merge, production change or Apple submission is performed
by updating this inventory.
