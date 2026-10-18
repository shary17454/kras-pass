# Terminal Multiplayer Version Recovery

Runtime source: `b8ef5d7c0819e9c3c355aba508d86216c2d6ea24`.
Branch: `fix/kras-network-update-required`, based on PR119.

Both incompatible hello and a server version_mismatch error now close/reset
the volatile online session, clear the resume token and retry schedule, abort
an active network match through the existing connection_lost path, and retain
a localization key for the rebuilt room browser. No fabricated match result
or player progression is awarded. Starting a fresh local or online session
clears the old error normally.

Arabic and English copy explains app/service incompatibility, asks the player
to check for an update or try later, and confirms offline local play remains
available. It does not assert that a store update actually exists. The room
browser discards stale room entries and retains the specific message across
deferred rebuilds instead of reverting to a generic connection failure.

## Verification

- Focused network suite: 234 assertions pass, including both terminal entry
  paths with an existing reconnect token, state cleanup, local lobby recovery
  and persistent Arabic/English screen text.
- Full gate: 366250 assertions, 393 script compile checks, 438 resources with
  zero inventory issues, authored race/boss regressions and 39 stability
  matches with zero failures. `/tmp/kras-version-ux-gate.stdout` and its
  evidence directory contain detailed results.
- Final compile after the visual probe coordinate correction passes393
  scripts: `/tmp/kras-version-ux-final-compile.stdout`.
- Native macOS Metal: four captures, Arabic/English in portrait/landscape,
  pass and are manually inspected. Text fits the viewport without overlap.
  `/tmp/kras-version-ux-visual-final-save/screenshots/` and
  `/tmp/kras-version-ux-visual-final.stdout`.
- Valid protocol2 network regression: real local Godot host/guest with two
  humans and two bots, seed609614, movement and guest reconnect pass; both
  report final scores[16,16,16,16], and the guest receives649 presentation
  snapshots. This tied result is not evidence of a winning human match or
  four-human coverage. `/tmp/kras-version-ux-network.stdout`. Maximum local
  server loop delay81ms is diagnostic, not an internet performance acceptance.
- Strict stdout guards pass for the focused suite, final compile and native
  renderer. Headless macOS CA enumeration diagnostics are environment limits,
  not a claimed clean import or a production TLS test.

The first visual probe failed all four bounds checks because it compared
logical canvas coordinates to physical window pixels under canvas_items
stretch. The screenshots showed valid layout. The final probe uses viewport
visible bounds, matching label coordinate space; no product geometry was
changed to force that test to pass.

These screenshots deliberately inject a version mismatch without contacting
an endpoint. They prove rendered error presentation, not production protocol
deployment. Physical iOS/device interruption and active-match route teardown
still require broader release QA. Protocol2 remains incompatible with old
online builds by design, and coordinated server/client rollout is required.
No main merge, Railway deployment, signed archive, Apple upload or App Review
submission was performed. Local Xcode27 remains the required archive tool.
