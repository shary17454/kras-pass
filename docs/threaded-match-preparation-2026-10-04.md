# Selected-match resource preparation

## Scope

Based on `e67e88507692d73d8ecfbab40437ca3a652a713b`, this adds background
resource preparation to the existing screen router, not a replacement match
framework. Quick Play, tournament progression, adventure, training, replayed
results and the online screen already enter matches through this router.

The selected controller and arena are planned, not all 39 games or all maps.
`MiniGameDef` and `ArenaDef` accept an optional `preload_resources` array for
future content, so new resources do not require a new menu/router code path.
The existing natural-world resources are planned according to the actual arena
scenery selection and the tank controller. `Arena.scenery_script()` is shared
by preparation and scene construction to keep routing consistent.

## Lifecycle and failures

1. Lock navigation and fade the previous screen.
2. Disable its processing while preparing the selected resources.
3. Poll threaded resource requests between frames; never retrieve a resource
   while its loading thread is still running.
4. Retain the loaded resources until synchronous scene setup completes.
5. Swap successfully, then release the preparation bank, hide progress and fade in.

Missing configuration/resources and preparation failure preserve the previous
screen and history. Its original process mode is restored, navigation unlocks,
and the progress indicator is hidden. The wait budget is 30 seconds. Godot has
no threaded-request cancellation API: after a wait timeout, the previous screen
is restored while the preparation node drains the outstanding request when it
becomes terminal, then frees itself. The timeout is not a claim that a stuck
native I/O worker has been canceled.

Resources may be reused from Godot's cache, but the bank retains only one copy
of each selected path and is not a permanent all-map cache. No player saves,
physics rules, matchmaking protocol, authentication settings or release numbers
are changed. Content validation rejects missing or non-bundled declared paths.

## Verification

- Final rendered transition suite: 737 assertions passed with Metal, including
  real Main Menu -> Match -> Main Menu, resource retention during setup,
  progress visibility through construction, rollback, deadline and worker drain.
  Log: `/tmp/kras-match-preparation-rendered-final.log`.
- Content suite: 121 assertions passed, including registry validation and locale
  parity. Log: `/tmp/kras-match-preparation-content.log`.
- Final compile: all 340 scripts passed.
  Log: `/tmp/kras-threaded-resource-final-compile.log`.
- Headless preparation suite before the final progress-visibility assertion:
  736 assertions passed. Log: `/tmp/kras-match-preparation-final.log`.
- Full core suite on the pre-guard preparation source: 30,860 passed and 1
  failed, exit 1, 2002.0 seconds. Log: `/tmp/kras-threaded-resource-core.log`.
  This is a failed qualification, not a green core run.

## Online generation guard follow-up

Waiting for resources creates a real interval in which the room can close,
disconnect, finish, or advance to a different server epoch. A controlled fixture
reproduced eight invalid transitions before the guard (20 assertions passed,
8 failed in `/tmp/kras-match-session-before.log`). The router now captures the
requested room/epoch before fading and validates the active game, arena and
seed both before preparation and before swapping. It does not start an obsolete
match after waiting for resources. Local matches are independent of this guard.

The expanded fixture passed 43 assertions, including malformed/missing match
data, a changed arena, lobby state and a still-valid playing session
(`/tmp/kras-match-session-expanded.log`). The actual rendered local transition
suite still passed 737 assertions after the guard
(`/tmp/kras-match-preparation-session-guard-rendered.log`). The final compile
passed 341 scripts (`/tmp/kras-match-session-compile.log`). Runtime log guards
passed for both suites. These are controlled session-state tests, not proof of
four online players operating the graphical lobby or production connectivity.

The long full core run began with the preparation implementation subsequently
committed as `cc04450e65f47158420629bd4345c7dfe160e2f7`, before this guard follow-up.
It completed with a failing Expert/Easy Gem Grab comparison (72 versus 74
total points), 30,860 other assertions passed, and exit 1. This prevents release
qualification; the final guarded source has not been given a passing full-core
claim from that older run.
That comparison currently alternates slot assignments while also changing the
world seed on every run, rather than pairing identical world seeds as its
comment claims. Both the failed gate and the comparison design need follow-up;
the assertion has not been weakened and no AI speed/score advantage was added.

## Rendered resource and gameplay measurement

The performance probe supports `--prepare-resources` to exercise the same bank
before setup, separately counting preparation frames and construction time:

```sh
/opt/homebrew/bin/godot --path . --rendering-method mobile --audio-driver Dummy \
  --log-file /tmp/kras-threaded-resource-perf.log tests/perf.tscn -- \
  --test-data-dir=/tmp/kras-threaded-resource-perf-save \
  --games=tank_arena,sabaq_sawarikh --prepare-resources --screenshots
```

On the shared Mac M5, Godot 4.7.1, 1920x1080, uncapped drawing, four Expert bots:

| Game | Resource preparation ms | Frames during preparation | Synchronous setup ms | Live simulation s | Mean ms | p95 ms | Worst ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tank_arena | 2749 | 568 | 3453 | 10.00 | 8.56 | 13.71 | 49.21 |
| sabaq_sawarikh | 399 | 152 | 1796 | 10.00 | 4.50 | 9.85 | 41.25 |

The process exited 0, its runtime log guard passed, and teardown returned to
50 nodes (initially 50). This run preceded the optional definition fields and
the final progress-visibility correction; those changes are covered by the
subsequent rendered transition and content tests, not claimed as this exact
performance measurement's source.

## Remaining qualification

Preparation frames prove that the loading wait yields to drawing on this Mac.
They do not prove faster total startup: preparation plus setup still took
seconds. Terrain generation, collision construction and first-use GPU pipelines
remain synchronous. In particular, natural terrain builds a 201x201 mesh; moving
file I/O off the main thread does not move that geometry work.

These brief shared-machine numbers are not a controlled before/after speedup,
iPhone/iPad frame-pacing, thermal, battery or audible-sound qualification. No
quality reduction or shorter game was used to obtain them. Proactive next-game
tournament prefetch, geometry-build optimization, all-map/orientation device QA,
complete source-matched network CI, production deployment and exact-source signed
App Store archive/upload/review submission remain separate open gates.
