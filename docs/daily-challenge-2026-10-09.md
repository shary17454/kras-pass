# Shared Daily Challenge And Local Records

Parent: `c9b96bd17098589fdb8e7417d608e4a465c9c11f`, branch
`feature/kras-online-random-rotation`. This is local source evidence, not an
Apple upload or a production deployment.

## Behavior

- UTC date and sorted catalogue determine the game, arena, character, three
  opponents, difficulty, seed and compatible modifier. Local unlock ownership,
  active profile selection and the last quick-play roster do not alter them.
- Daily trial access does not permanently unlock characters or games.
- Attempts persist before launch. Completed attempts, best score and best
  finish time belong to the original profile. Race time uses the player's
  centiseconds, not the duration of the entire match.
- One unique victory per day awards 12 gems. Repeated callbacks, subsequent
  wins and old legacy claim records do not grant the reward twice.
- Interrupted matches and ties cannot claim victory rewards. Existing saves
  remain schema-compatible; record history is bounded to 32 entries and claim
  history to 90 dates. This is local/offline storage, not an anti-clock-tamper
  server service or an online leaderboard.
- The daily heading is compact, metadata wraps, and Start stays visible
  outside the scrollable details, including at 1.4 text scale.

## Evidence

The original rendered layout failed horizontal containment once and placed
the start action below the viewport. After the fix, the shipping daily screen
passed 149 headless layout assertions and 153 actual Metal assertions across
Arabic/English at 540x960 and 1280x720. All four final captures were inspected.
The test checks horizontal containment, real localized labels and the Start
button before and after scrolling. It is desktop Godot rendering, not a
physical iPhone/iPad test.

The first focused service run contained a nonexistent test API and a script
error despite its exit status. It is rejected evidence. Corrected service
tests pass, covering fixed configuration, profile changes, repeated claims,
legacy saves, ties, interruption, race units and bounded history.

Final full regression: 393877 assertions, 195.2 seconds, exit 0. Compilation:
all 436 scripts pass. The Godot log checker passes each final test/compile log
individually; `git diff --check` passes. Sandbox CA certificate errors and
intentional negative-test diagnostics remain in raw logs, not removed.
Evidence is retained in `../qualification-daily-challenge-2026-10-09/`.

Runtime fingerprint:
`37696fac7010eab8bb7b8ff97a26940833867e919f08737b89507243948a694d`.
Existing c1-source network/balance campaigns remain c1 evidence, not evidence
for these newer changes. They were not cancelled or restarted. These edits
remain local while the branch's cancel-on-push network campaign runs.

## Remaining Release Gates

Whole-scope content/device acceptance, current-source network and balance
qualification, production integration, and an exact-source signed Xcode 27
archive remain required. The older 1.1.11 (110) archive excludes these changes
and must not be uploaded as the latest source. No main merge, Railway database
operation, device installation, archive, upload or review submission occurred
in this daily correction.
