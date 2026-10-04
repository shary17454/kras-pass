# Online start handoff during resource preparation

## Source and reproduced defect

Based on `fdd9329fa14bf7f12e0acbfa71ec93fa7ac30364`, the online screen called
`SceneRouter.start_match()` directly from the server start signal. The router
rejects concurrent transitions. A newer start arriving during an asynchronous
resource wait was therefore lost, even though the older match was correctly
rejected by the session guard.

A controlled lobby-screen fixture reproduced the lost request before the fix:
two assertions passed, one failed, exit 1.
Log: `/tmp/kras-online-handoff-before.log`.

## Runtime change

The online screen retains only the latest requested match with its room and
epoch. It waits for the router's deferred transition-finished signal, checks
that this same online screen is still active, and reuses the existing router
session guard to validate room, epoch, connection, game, arena and seed.
The request is consumed before launch or discarded when obsolete. Repeated
completion signals cannot launch the consumed request again.

This does not change the server protocol, host authority, local navigation,
readiness rules or the existing router rejection of concurrent button presses.
The screen-bound signal callbacks are not a global persistent match queue.
It does not add host migration or prove four-client reconnect behavior.

## Executed checks

- Handoff fixture: 34 assertions passed headless, exit 0, 2.9 seconds.
  `/tmp/kras-online-handoff-expanded.log`.
- The same fixture rendered with Metal Forward Mobile on Mac M5: 34 assertions
  passed, exit 0, 1.2 seconds. `/tmp/kras-online-handoff-fixture-rendered.log`.
- Session-generation guard: 43 assertions passed, exit 0.
  `/tmp/kras-online-handoff-session.log`.
- Real local Main Menu -> Match -> Main Menu and preparation failure/drain:
  737 assertions passed headless, exit 0, 30.1 seconds.
  `/tmp/kras-online-handoff-preparation.log`.
- All 342 scripts compile, exit 0. `/tmp/kras-online-handoff-compile.log`.
- Runtime/compile log guards and `git diff --check` passed for these completed
  runs. The headless macOS CA lookup warning remains an environment warning.

The fixture covers latest-request coalescing, duplicate completion signals,
changed room/epoch/game/arena/seed, missing match data, disconnected/local/lobby
states, results, null/local requests, changed screen ID and another screen
instance. It overrides match launch to observe handoff without pretending to
have a live server. It is not a four-online-player integration result.

## Unfinished rendered check retained

The initial sandboxed rendered preparation invocation failed to reach Godot's
project log and emitted macOS HIServices errors. A sample of the owned process
showed AppKit's event loop before project startup; it was explicitly terminated.
Diagnostic: `/tmp/kras-online-handoff-rendered-startup.sample`.

A subsequent local Metal preparation invocation reached Main Menu -> Match ->
Main Menu, but exited without the required completed test summary and reported
four ObjectDB leaks on stdout. Its log guard failed. Exit 0 alone is not a pass:
`/tmp/kras-online-handoff-local-rendered.log`. The reason for that incomplete
run is not established. The passing focused Metal handoff fixture and passing
headless preparation run do not erase this incomplete rendered qualification.

## Open release gates

Full core and networking CI on the final source, full graphical lobby/play/
reconnect testing, physical-device performance and orientation QA, production
deployment and exact-source Distribution archive/upload/App Review remain
required. No main merge, production enablement or Apple submission is claimed.
