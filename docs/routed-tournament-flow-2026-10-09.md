# Routed Tournament Completion And Tie Limit

Parent: `f3f84084daddbe4de515199ee3f399ad7ab58529`, branch
`feature/kras-online-random-rotation`.

## Tested Path

The new regression launches a temporary TournamentSession, retains only a
WeakRef in the fixture, and exercises shipping SceneRouter, match simulation,
standings, Next Game, checkpointing, champion podium and Quit actions. This
tests the completion-owner fix without keeping the session alive artificially.

Four cases use the same manual three-game playlist: gem_grab, ring_rumble,
quick_draw. Rosters: 1 human + 3 bots, 2 + 2, 3 + 1, 4 + 0. Keyboard profiles
0/1 and per-slot touch providers are assigned without duplicating keyboard
profiles. Inputs only acknowledge the human instruction card; humans otherwise
remain idle. This is not competitive human playtesting, touchscreen gesture
acceptance, controller hardware testing or physical iPhone/iPad evidence.

All matches finish naturally using their actual rules, scores, round lengths,
normal bot tier and seed 1337. No result, winner, timeout or score is injected.
Between matches, the test activates the real Next Game action. It checks the
same session identity, four standings, accumulated displayed awards, recorded
completion, cleared checkpoint, actual podium, return to main menu, one routed
screen and release of the completed session.

## Natural Tie Case

An additional four-human manual playlist contains three quick_draw matches.
With no reaction input during play, all scores tie naturally. Tournament points
are [9,9,9,9]. The shipping decider runs three further 20-second matches,
all still tied. It then completes with champion -1 and shared_champions
[0,1,2,3], rather than looping forever or choosing by slot order.

Focused result: 231 assertions, 21.5 seconds, exit 0, across 18 naturally
completed matches. The Godot log checker passes the focused log. Earlier
one-roster and four-roster samples passed 41 and 161 assertions respectively;
these are superseded samples, not extra matches to add to the final total.

The complete regression suite subsequently passed 394134 assertions in
203.0 seconds (exit 0). The compilation check passed all 438 scripts (exit 0).
Both logs passed tools/check_godot_log.sh individually; tests mode was used
for the full regression log. The raw logs retain the documented sandbox CA
warning and expected negative-test diagnostics; these are not erased.

Logs: kras-routed-tournament-full-20261009.log and
kras-routed-tournament-compile-20261009.log in the evidence directory below.

Rejected fixture runs are retained: initial use of a nonexistent NORMAL enum,
and a typed-array assignment failure while adding the tie case. The latter
owned local process was identified and stopped with SIGTERM (exit 143) after
the explicit script failure. No external campaign was cancelled/restarted.

## Source And Limits

This change adds tests only, not shipping gameplay or thresholds. Runtime
fingerprint remains
`71b5a52a33d4be33e306e93acdc777fdf3b7de41c82e8e463cbc88bd7901ed7c`.
Evidence is retained in `../qualification-routed-tournament-2026-10-09/`.

This proves the specific routed tournament flow and natural unresolved-tie
ending, not all 39 games, maps, modes, online rooms, physical controls or
performance. Weekly challenge remains absent. Current-source all-game
qualification, physical-device acceptance, production integration and an
exact-source Distribution archive via local Xcode 27 remain release gates.
The live c1 campaigns retain their own source identity. No main merge,
production database action, device installation, archive, upload or App Review
submission happened in this tournament verification.
