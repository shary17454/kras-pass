# Status Visual Preparation and Reuse

Runtime source: `c377dfd62fa3e43c5b20acbaa124ab8185e5422e`.
Branch: `perf/kras-fighter-hud-suboperations`, stacked on diagnostic PR 106.
No main merge or Apple release was performed.

## Evidence and Change

Opt-in tracing split fighter integration, physics, contacts, rig, state visuals
and ground effects, plus HUD chip values, effects, layout and offscreen cues.
The exploratory report `/tmp/kras-frame-effects-diagnostics.json` associated
long script wall intervals with first state-visual construction (19.642 ms)
and status-label rebuilding (48.032 ms), not ordinary movement or collision.
These inclusive wall intervals are not exclusive CPU measurements and do not
prove that every renderer/system stall has the same cause.

Rendered fighters now build hidden persistent state visuals during setup.
The builder is idempotent; the existing lazy fallback remains for compatibility.
Headless simulation does not prepare rendered visuals automatically.
HUD chips prepare one hidden label for each registered power-up, reusing those
labels when effects appear, expire or change. Glyph, color and active order are
updated; unknown unregistered IDs cannot grow the pool. Unchanged labels are
not hidden and shown again. Existing responsive font sizing still applies.
No gameplay rules, graphics quality, content or AI were reduced.

## Final Native Observation

Godot 4.7.1, macOS Apple M5, Metal mobile, portrait 720 x 1280, quality 2,
cap 60, four Expert bots, synthetic touch controls, seed 72, tag_hunt on
star_meadow. All four state-visual trees and four pools of 22 status labels
were present before play. Capture completed 28 live seconds and all bots moved.
Runtime log guard passed and the screenshot was inspected.
Report, screenshot and log: `/tmp/kras-status-pool-final-render` with `.json`,
`.png` and `.log` suffixes.

- Steady 25.02 seconds: 59.55 FPS, p95 18.359 ms, p99 19.941 ms.
- Worst steady frame: 118.739 ms; one frame exceeded 100 ms.
- State-visual maximum interval: 0.154 ms; HUD-effects maximum: 1.118 ms.
- Node count after teardown: 50 to 50.
- Static memory after: 129.04 MiB; peak: 132.15 MiB.
- Setup: 3559.217 ms, which is still a startup-latency concern.

An intermediate prepared run at `037450f` had no steady frame above 100 ms
and 69.382 ms worst; it must not replace the less favorable final result.
The initial diagnostic run had 464.119 ms worst and 58.68 FPS. These short
single-machine observations suggest removal of the identified allocation
spikes, not controlled statistical proof of all-game 60 FPS or phone performance.
Preparation trades startup work and resident hidden nodes for less in-play
allocation. Startup loading, remaining stalls, physical thermal/battery tests
and all-game qualification remain open.

## Checks and Release Boundary

Final HUD suite: 3321 assertions passed, including ar/en, portrait/landscape,
catalog layouts, pool identity/size, status colors/expiry, unchanged visibility,
idempotent hidden state visuals and teardown checks. This is not rendered
gameplay QA of all 39 games. Log: `/tmp/kras-status-pool-final-tests.log`.
An initial new-test variable shadowing parse error was corrected; its failed
run `/tmp/kras-status-prepared-tests.log` is not counted as passing evidence.
Lifecycle: 13 passed, `/tmp/kras-status-pool-final-lifecycle.log`.
All 388 scripts compile, `/tmp/kras-status-pool-final-compile.log`.
All final log guards passed; the known sandbox CA lookup is allowed separately.
`git diff --check` passed. A full regression was not run on this source.

No iOS export, Archive, signing, upload, processing or App Review occurred.
Local Xcode 27 remains the release path, not Xcode Cloud; fresh release-source,
version/build and physical-device gates must be satisfied before submission.
