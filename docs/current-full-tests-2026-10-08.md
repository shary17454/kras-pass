# Current Full Test Gate

Tested commit: `282669db65d7f2b92b50c1c5e26cef69d1ff099b`.
Branch: `feature/kras-online-random-rotation`.
Godot 4.7.1 official, headless, fixed simulation rate 60.
No application/test source changed during the run; only evidence documents
were added. Saves were isolated at `/tmp/kras-current-full-282669d-save`.

The full `tests/test_runner.tscn` run completed with exit zero and 392440
assertions passed in 296.6 seconds. The strict `tests` log guard passes:
`/tmp/kras-current-full-282669d.stdout`.
Engine log: `/tmp/kras-current-full-282669d.log`.
This includes the expanded survival exposure probe tests, native controller
contracts, real three-lap race integration and current gameplay regressions.

Stage-zero inventory also exits zero with its strict runtime guard:
531 resources, 22 autoloads, 27 routes, eight characters, zero issues.
Log: `/tmp/kras-current-inventory-282669d.stdout`.

The macOS headless engine prints a system CA retrieval warning at startup.
This is not a positive network/TLS test and is not suppressed; these runs
qualify only the local test scopes. No GDScript/runtime/leak diagnostic
matched the existing strict guards.

Fresh public production `/health` returned:
`{"ok":true,"authentication_ready":true,"multiplayer_enabled":false}`.
That proves endpoint availability only; production online gameplay remains
disabled. No production data, environment variable or deployment changed.

Passing these tests does not resolve all balance warnings, prove rendered
iPhone/iPad performance, temperature/battery behavior, actual positive Apple
login, current Railway source synchronization or exact-source signing.
The Mac UI remains unavailable while locked. No local Xcode archive, Apple
upload, processing, withdrawal or review submission occurred in this gate.
