# Natural-round balance campaign

The balance tool now defaults to full definition-duration rounds. Explicit
`--clipped-rounds` retains short exploratory sampling; reports identify the
mode and each game's actual window. Lap races keep their finish-line logic and
ten-minute simulation guard. Ordinary rounds have a guard of at least their
full window plus 90 seconds, including boss rounds and sudden death.

The default catalogue includes all 39 definitions, including four bosses.
Unregistered `--only` selection exits with status 2 rather than producing an
empty successful report. Attempted/completed expert-versus-easy samples are
recorded separately; incomplete comparisons are a severity-2 qualification
failure. Characters from unfinished baseline samples do not add appearances.

Verified locally on this patch:

- `/tmp/kras-natural-balance-policy-final.log`: 86 assertions passed, exit zero.
- `/tmp/kras-natural-balance-compile.log`: 324 scripts compile, exit zero.
- `/tmp/kras-natural-balance-invalid.log`: invalid game selection exits 2.
- `/tmp/kras-natural-balance-draw.log`: Quick Draw, two natural baseline rounds,
  two mirrored difficulty rounds and two mutator/chaos smoke rounds; exit zero.
  Average baseline duration 75.0 seconds, no tied baseline, both smoke rounds
  complete. Reports: `/tmp/kras-natural-balance-draw-report/`.

The new manual `Natural Balance Campaign` workflow reads the catalogue rather
than duplicating IDs. It schedules 24 baseline, 12 difficulty and two smoke
matches per game: 1,482 matches for the current 39 definitions. Three workers
maximum, no cancellation of an existing campaign, independent reports and
checkout/commit evidence. It verifies completion counts and uploads evidence
even on failure. The existing Game Quality workflow can call this campaign
with its `balance_campaign` dispatch input on a development ref, without needing
to merge the new workflow to main first. This selects the balance campaign
instead of also starting the full network matrix. Dispatch and completion
evidence are recorded separately from the local tool checks above.

## Dispatched Campaign

GitHub run `37108335239` was accepted on 2026-10-03 from exact source
`0b21cac95075705a3ee85641e33e3aa680bcd879`, development ref
`feature/kras-balance-campaign-dispatch`. The catalogue job completed
successfully. A live snapshot showed three simulation jobs in progress
(tank_arena, ring_rumble, crumble_court), 36 queued, and the ordinary network
matrix skipped as intended. This is execution evidence, not a campaign pass.

Run: https://github.com/shary17454/kras-pass/actions/runs/37108335239
Review: https://github.com/shary17454/kras-pass/pull/10
Do not dispatch a duplicate just because later observations are slow.

Remaining qualification: run the full campaign, inspect small-sample warnings
and character exposure fairness, vary arena/seed/player compositions, and
resolve real balance issues. Two baseline matches are functional evidence for
the tool, not statistical proof of character balance. Full game regression,
physical-device performance, current-source online matrix and Apple release
remain separate gates. Local engine logs retain the system CA warning.
