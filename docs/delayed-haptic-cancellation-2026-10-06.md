# Delayed Haptic Cancellation

Runtime source: `3132a061e8f573ccf061d7200fe0e4161844cec0`.
Branch: `fix/kras-cancel-delayed-haptics`, based on PR 108.

## Reproduced Defect and Correction

The success pattern scheduled two SceneTreeTimer callbacks after its first
pulse. Turning vibration off or entering the background did not cancel those
callbacks. A pulse-capturing test double reproduced both defects: 295 passing
assertions and two failures, with three pulses instead of the expected one.
Console: `/tmp/kras-haptic-cancel-red.stdout`.

The router now owns the two pending beats, cancels them on vibration changes,
background entry, `clear_all`, or teardown, and stops frame processing when
the queue is empty. An uncancelled success still has three beats. The runtime
no longer creates per-beat timers or closures. Gamepad rumble is unchanged.

## Completed Focused Checks

Godot 4.7.1, isolated test data, fixed FPS 60 for gameplay suites:

| Check | Result | Console |
| --- | --- | --- |
| Input sources and pulse cancellation | 302 assertions passed | `/tmp/kras-haptic-cancel-final.stdout` |
| Lifecycle | 13 assertions passed | `/tmp/kras-haptic-cancel-lifecycle.stdout` |
| Local party core | 4171 assertions passed | `/tmp/kras-haptic-3132-party.stdout` |
| Compile | 388 scripts compiled | `/tmp/kras-haptic-3132-compile.stdout` |
| Complete runner, verbose | 365835 assertions passed, exit 0, 463.3 s | `/tmp/kras-haptic-3132-full.stdout` |

The console log gate accepted these results. The known macOS sandbox
system-CA diagnostic is distinct from gameplay failures. The pulse tests
capture the platform-call seam; they do not prove physical haptic feel.

The prior focused verbose tank/network probe at parent `94b6f68` passed
165 assertions without an exit leak warning (`/tmp/kras-exit-audio-probe.stdout`).
This does not identify or fix the intermittent full-suite ObjectDB leak.
The new full run also passed the corrected console gate without an exit leak
warning. One clean run is not proof that the prior intermittent leak was
caused by the haptic timers or has been eliminated. Runtime source remained
unchanged throughout this run; only this documentation was added.

## New CI Import Blocker

GitHub run `37409510505`, PR 108: the completed core job `112094539390` and
ring-network job `112094539512` both failed before tests, while importing a
fresh checkout. `gui/theme/custom` loads `assets/fonts/ui_theme.tres` before
the five fonts' `.godot/imported/*.fontdata` files exist. Logs are retained at
`/tmp/kras-ci-108-core.log` and `/tmp/kras-ci-108-ring.log`.

A minimal isolated project with the same font directory and project theme
reproduced the missing fontdata/theme errors:
`/tmp/kras-fresh-theme-repro.stdout`. It also emitted sandbox user-directory
and CA diagnostics, so this is a reproduction, not a clean import result.
Do not weaken the import error gate or call these failures network-gameplay
failures: those jobs did not reach networking checks. Repair and qualify
clean-checkout import separately.

## Release Boundaries

No main merge, production deploy,
new signed Archive, upload, processing, or Apple review submission occurred.
The release path remains local Xcode 27, not Xcode Cloud. All-game rendered and
balance QA, physical iPhone/iPad performance and production acceptance remain
required; this focused fix is not completion of the full product scope.
