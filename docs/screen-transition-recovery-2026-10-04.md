# Screen transition failure recovery

Branch `fix/kras-screen-transition-rollback`, based on checkpoint PR #52.
Load and instantiate the replacement screen before tearing down the current
one. Only successful forward navigation pushes history; failed back navigation
restores its entry, including same-ID reloads. Failed transitions clear the
fade and release the busy guard. Concurrent requests remain rejected.

`go_to` now returns a success boolean instead of void. Existing callers may
continue ignoring it; `back` consumes it to restore history reliably. `_swap`
is internal and also returns success. The script-loading boundary is isolated
for fault injection; the production path still uses the existing screen registry.

The unused `_pending_args` field was removed after a repository-wide GDScript
search found only its declaration and assignment. It unnecessarily retained
screen arguments after navigation. This is not a measured memory-leak claim.

## Evidence

The initial fault-injection test, with a null screen script returned at the
loading boundary but the original teardown order, failed four assertions:
previous node lost/queued for deletion, forward history changed and back entry
lost. Five assertions passed. Log `/tmp/kras-router-recovery-before.log`.
This is a controlled unavailable-resource scenario, not a claim that a shipped
screen script was missing.

Final focused test: 18 assertions passed (`/tmp/kras-router-recovery-final.log`).
Includes null-script recovery, successful real main-menu navigation, old-node
release, same-ID failed back navigation, duplicate request rejection, visible
overlay and busy guard restoration. Intentional Router error logs remain
visible for injected failures; no SCRIPT ERRORs are accepted.

Existing systems suite: 248 assertions passed (`/tmp/kras-router-systems.log`),
including construction and back support for registered non-match screens,
the actual router holder and playable app entry. Compile: 337 scripts passed
(`/tmp/kras-router-compile.log`). Test save directories were isolated.

Godot log guards and diff checks are run before publication. The focused suite
is included in the full test runner. No deadlines or assertions are relaxed.

## Limits

This does not catch arbitrary errors inside a screen's setup/build method or
add an asset preloading system. Real missing-resource paths, fade presentation
on device, complete gameplay/CI qualification, Railway deployment, Distribution
Archive and App Review remain independent requirements. No main merge or app
upload is performed by this branch.
