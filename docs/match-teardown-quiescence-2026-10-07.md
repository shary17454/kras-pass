# Match teardown quiescence

## Reproduction

The rendered all-game smoke on candidate source
`0f989d52c5dbc39ef7a143e61c1b830fddc49e17` reported repeated
`pool 'powerup_pickup' used before define()` errors after returning to the menu.
The stack reached `PowerUpSystem.tick()` from `MatchScene._physics_process()`.
The router calls teardown before deferred queue_free; the retired match could
still process after teardown drained the shared pool factories.

That old run was intentionally interrupted after reproduction. Its process
exit was 0, but it did not complete the 78-shot campaign, and its error log is
not a passing result. Interruption also produced renderer shutdown diagnostics.
Evidence: `/tmp/kras-candidate-111-all-games-visual.log`.

## Change

Parent: `ac51c09` (reacquisition qualification, before candidate build metadata).
`MatchScene.teardown()` now marks the match retired, disables its subtree
before cleanup, and ignores repeat calls. Direct physics/HUD callbacks also
ignore retired matches. This prevents a second teardown from draining pools
already created by a successor. Live movement, scoring and AI rules are unchanged.

The visual fixture now checks errors after navigation/cleanup, not merely
before a screenshot. A passing capture cannot hide an error during retirement.

## Executed checks

- Compile: 415 scripts, exit 0; `/tmp/kras-teardown-compile.log`.
- Lifecycle: 19 assertions, exit 0; `/tmp/kras-teardown-lifecycle.log`.
  The new case retires a live match with an overdue pickup spawn, invokes
  late callbacks, verifies frozen simulation time and no new error, then
  verifies repeated teardown leaves a successor probe pool intact.
- Network preparation cleanup: 7 assertions, exit 0;
  `/tmp/kras-teardown-network-cleanup.log`.
- Matches integration: 6960 assertions, 265.5 seconds, exit 0;
  `/tmp/kras-teardown-matches.log`. Includes all 39 games with shortened test
  round budgets, pause/restart, controller loss, multiple rounds, difficulty
  samples and three-lap races on eight circuits. Not full natural balance.
- Actual Metal 4.0 Forward Mobile / Apple M5 rendered smoke: 78 captures,
  39 default arenas, Arabic, portrait 540x960 and landscape 1280x720,
  one human slot plus three AI, three extra play seconds each, zero failures.
  `/tmp/kras-teardown-all-games-visual/visual-report.json` and `screenshots/`;
  runtime log `/tmp/kras-teardown-all-games-visual.log`, exit 0.
- Runtime log guard passed for all four checks above and compilation.
- `git diff --check` passed.

These checks ran with the exact three-file patch subsequently committed;
no source edits occurred while the checked processes were running. Only this
documentation was added after completion. Headless checks retained the known
macOS system CA access diagnostic; the existing log guard accepts that
environment diagnostic, not arbitrary runtime errors.

Manual pixel inspection: goal_guard portrait and landscape. The field,
players, score symbols, goal and controls are visible. This does not certify
every screenshot's visual quality or usability on a physical screen.

## Release status

Candidate 111 archive remains unchanged and does not include this fix. Do not
upload it as the fixed release. A new committed release source/build, affected
full qualification and fresh LOCAL Xcode 27 archive are required.

Balance campaign 37616445234 tests parent runtime source 96c53f3, not this patch;
at last inspection two jobs succeeded and remaining jobs were queued. No new
campaign was dispatched. Production multiplayer remains unqualified/disabled;
no production deployment, database export, main merge, phone install,
App Store upload, screenshot replacement or review submission was performed.

Physical device performance, heat/battery, native screenshots, production
authentication/subscriptions and Internet multiplayer are separate open gates.
