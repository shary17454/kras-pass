# Current Core qualification - 9 October 2026

GitHub run [37939920719](https://github.com/shary17454/kras-pass/actions/runs/37939920719)
completed successfully. Downloaded artifacts independently identify checkout
`76813931a747040469036e44e4e7de0d386ee109`, tree
`e922119cad7531750a1a215954affefb3188ee3f`, the intended head matching the
checkout, and no tracked changes. This includes the Boss warning reaction-delay
fix. Simulation fingerprint: `a33587770b6fbe8bc48988c0b8f0ad0a41c3e96337d8be9eb418787e23661959`.

## Checked evidence

- Godot 4.7.1 compiled 444 scripts.
- Completed regression suite: 406143 assertions, 486.9 seconds.
- Stability report: 117 matches across 39 default arenas and three cycles;
  global and per-match failure lists are empty. Timed rounds are shortened,
  race laps unchanged; this is not device performance or natural balance proof.
- Server tests before captures: 265 passed, six capture-dependent tests skipped.
  After actual Godot captures: 271 passed, zero failed, zero skipped.
- Four actual Godot peers completed hurdle_dash, goal_guard and ring_rumble.
  All agreed on three round histories, standings [8, 7, 12, 7], champion slot 2
  and completed tournament. Host and one guest reconnected; two other guests
  stayed connected. This is localhost networking, not Railway production.
- All 23 downloaded stdout/log files passed the repository's strict Godot log
  checker, using tests mode for tests.stdout and import mode for asset import.

A first broad diagnostic rejected every ERROR line. Inspection found exactly
four intentional failure-injection messages: one failed save write and three
failed screen loads in router recovery tests. Their backtraces identify the
corresponding test suites. They are retained in the raw evidence, not deleted
or described as a wholly error-free execution. The repository checker and
completed assertions independently passed.

Raw artifacts are preserved outside Git in
`../qualification-core-7681393-2026-10-09/`.

## Limits and next gate

The later ea33807 transport-budget tests are not part of this CI checkout;
their separate local 275-test result is documented in
[WebSocket budgets](websocket-budgets-2026-10-09.md). No shipping runtime code
changed in that commit. This does not make CI a test of every later commit.

The new all-39 natural balance campaign 37939933912 remains in progress.
The older full network campaign 37932029724 belongs to a different source.
Neither incomplete campaign is accepted here. iPhone/iPad performance,
controller QA, production backup/restore and migration approval, Railway
connection, final-source native archive, upload and review remain separate
uncompleted gates. No main merge, deployment, archive or Apple submission was
performed by this qualification.
