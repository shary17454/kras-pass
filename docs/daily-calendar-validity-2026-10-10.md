# Daily Challenge Calendar Validation

Baseline commit: `898e9a1` on `feature/kras-online-random-rotation`.
Godot 4.7.1 official. The tested working-tree change affects only daily-plan
date validation and its regression tests; this document does not change the
runtime. Runtime fingerprint, matched between checkout and imported test copy:
`dfd58377f9b77ee3f17031c1492a0edd1401d4ea60a64a677a549205fd035e11`.

## Confirmed Defect And Repair

The previous eight-digit regular expression accepted nonexistent dates:
month zero or 13, day zero, short-month overflow, invalid leap days and year
zero. Its end anchor also allowed a trailing newline. An initial regression
run reproduced 16 failures, with 265 passing assertions and exit 1.

`Daily.plan()` now requires exactly eight digits and a valid proleptic
Gregorian date in years 1 through 9999. February follows the 4/100/400-year
leap rule. Existing valid dates retain their original key and hash-based seed
algorithm. No catalogue, game rules, rewards, UTC day boundary, save schema or
existing stored data were rewritten.

The validator gates daily-plan creation. It is not a new authentication system
for arbitrary externally forged setup dictionaries or historical save rows.
Invalid plan output follows the existing empty-plan handling: no match config,
no new attempt, and no mutation of profile progress. Old stored claims and
records are not deleted merely because their key is unusual.

## Verified Results

- Focused final daily suite: 334 assertions, exit 0, strict test guard passed.
  Covers invalid/valid dates, leap centuries, unchanged seed generation,
  empty-plan flow, unchanged saved progress, interrupted/repeated attempts,
  original-profile ownership, old claims and damaged-record normalization.
- Complete regression: 407633 assertions, 262.5 seconds, exit 0, strict test
  guard passed. Includes the previously added Tank close-steering test.
- Compile check: 450 scripts, exit 0, strict guard passed.
- Local server contract tests supplied with six actual captures from this
  complete Godot run: 276 passed, zero failed, zero skipped, exit 0.

Expected memory-warning, controller-disconnection and replay-budget warnings
from regression fixtures remain in stdout; this is not a zero-warning claim.
Raw failed and passing evidence is preserved at
`../qualification-daily-calendar-2026-10-10/`.

## Release Limits

Core run 38019424372 was verified terminal-success on its older c9777a7
checkout. That immutable run does not include this repair or its new test.
Its source was neither cancelled nor silently relabelled as current.

The independent Tank difficulty warning is still unresolved. Current-source
39-game balance/network acceptance, remaining product requirements, physical
device/controller/energy QA, production backup/deployment qualification and
an exact-source signed native release remain open. No READY classification,
new-stage acceptance, main promotion, Railway deployment, archive, Apple
upload or review submission is claimed by this fix.
