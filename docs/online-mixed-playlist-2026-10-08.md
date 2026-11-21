# Online mixed-minigame tournament editor

## Implemented

The host lobby now edits the existing server tournament entry list rather than
restricting tournaments to the maps of one minigame. Each entry has a game,
an arena, its order, a move-earlier button and a remove button. Add selects an
unused valid game/arena pair; all 39 registered online minigames are available.
The server's existing 1-39 entry budget and duplicate-pair rule are enforced
locally before publishing. The last entry cannot be removed.

Rotation changes preserve the selection. Switching points/cups preserves the
custom list, target and rotation. Sequential edits share the current draft
instead of overwriting a preceding edit with an older captured list. After
turning a tournament off, callbacks from its old controls cannot resurrect it.
The lobby's initial game/arena follow the first playlist entry. Guests see
the selected list without host editing controls. Race laps are exposed when
any selected game is a race, not only when it is the initial game.

No new protocol fields, authority privileges, online endpoint or backend
deployment were introduced. The server continues to validate all configuration
and result operations and to enforce host-only control.

Random-no-repeat now uses a seeded bag of distinct games, with an independent
seeded arena bag per game. A game with several maps cannot recur before all
other selected games have run. Each game's arenas are exhausted before reuse,
and immediate cycle-boundary repeats are avoided when a choice exists.
Single-game tournaments retain map rotation. Independent random and manual
rotation remain unchanged. The same seed/config produces the same new schedule;
its schedule need not match the older entry-based algorithm.

## Tests and visual QA

- Network/GUI regression suite: 400 assertions passed.
- Room and tournament tests: 72 passed, including a new four-participant
  three-game sequence (ring, ball, hurdles), guest authority rejection,
  reconnect identity and matching final standings.
- After the no-repeat policy correction, room and tournament tests: 74 passed.
  Two new regression tests failed against the old policy, then passed. Across
  64 seeds, mixed-game cycles exhaust every distinct game, independent arena
  cycles exhaust their maps, and cycle boundaries do not immediately repeat
  when alternatives exist. Selected entries stay unchanged. These are rotation
  policy tests, not natural gameplay or character balance simulations.
- Full Node suite without capture fixtures: 235 passed, six explicitly skipped.
  These skipped tests require actual Godot world snapshots; do not report 241
  passing tests from that invocation.
- Final full Node suite after the policy correction: 237 passed, six skipped,
  zero failures (243 total). Capture-dependent cases remain unqualified here.
- All 424 scripts compile.
- Actual Godot rendering: Arabic and English at 1920x1080 and 1080x1920.
  Every entry's game/arena identity and screen bounds were checked after
  scrolling it into view. Screenshots were inspected. Portrait stacks the
  dropdowns; landscape uses a compact row. Long option names cannot expand
  the row beyond the screen.
- A first presentation check failed because it scrolled to the old bottom
  position, while rotation now precedes the playlist. The check now scrolls to
  the rotation control and verifies each entry separately. An actual horizontal
  expansion found in screenshots was corrected, not merely excluded from QA.
- Full final-source Godot result: incomplete. The run progressed into match
  integration and difficulty samples, then available storage fell to 101 MiB.
  A real profile write failed and replay preparation failed outside the
  intentional save-failure fixtures. Only this task's identified Godot process
  (PID 66613) was terminated with SIGTERM; exit 143 was confirmed. No completed
  positive test summary exists. Do not count this run as passed.

The room test uses controlled server clients and supplied scores; it is not
proof of three naturally played rounds by four Godot processes. The rendered
lobby is a presentation fixture, not a production room. Those distinctions
remain explicit in the qualification status.

## Remaining gates

- A mixed-game tournament with four actual Godot peers and gameplay-derived
  results still needs end-to-end qualification.
- The real four-peer mixed-game scenario was subsequently qualified for three
  games on loopback, including no-repeat and reconnect; see
  `online-mixed-real-peers-2026-10-08.md`. Production networking and wider
  mixed-playlist coverage remain separate gates.
- The first full run encountered a temporary settings write error during low
  disk space and was superseded by later handler changes. It is not final
  source qualification; its identified process was terminated and exit 143
  confirmed. Only this task's candidate-112 DerivedData build/cache
  directories were removed; its signed archive, export and logs were retained.
- The subsequent final-source run also hit low disk space; its compressed
  evidence is `full-final-interrupted-low-disk.stdout.gz`. Reclaim storage with
  owner approval before rerunning the full suite or archiving. No arbitrary
  user files or browser site data were deleted.
- Current-source all-game balance/stability, device performance, production
  Railway enablement, local Xcode 27 archive, upload and App Review remain open.

## Local release access check

Chrome's current authenticated App Store Connect page for app 6801506973
shows version 1.1.10, build 107, Ready for Distribution. This is not evidence
that current feature-branch changes were uploaded. The installed local
Apple Distribution identity for team 4HM66AD594 was read-only verified again;
no P12 import, password request or certificate changes were performed.
No new archive, upload or review submission was performed in this check.

Evidence: `docs/qa/online-mixed-playlist-2026-10-08/`.
