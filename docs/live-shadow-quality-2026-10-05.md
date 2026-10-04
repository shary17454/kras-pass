# Live Shadow Quality Qualification

Implementation source: `54e6cf46a8accb93cc353a6efc2d087125386bf5`.

## Defect

The existing settings service updates the frame ceiling and resolution scale
when graphics quality or battery saver changes. Arena sun shadows, cascade
count, split blending and angular softness were selected only during initial
construction. Enabling saver from the paused match therefore retained the
existing higher-cost shadow configuration until another arena was built.

The regression reproduces this before the fix: 54 assertions passed and 13
failed in `/tmp/kras-live-shadow-red.log`, exit 1. The failures include retained
shadows in saver and stale cascades/softness after live tier changes.

## Fix

Arena shares its initial and live sun-shadow quality application and listens
once to graphics quality, battery saver and reset-to-default settings changes.
Tier 0 disables sun shadows; tier 1 uses two cascades without blending or
angular softness; tiers 2/3 retain the existing four-cascade configuration.
The listener is automatically removed when the arena is freed.

World-authored sun direction, color, intensity, contact bias, environment,
terrain, physics objects and spawn points are preserved. No scene rebuild,
network protocol change, save migration or new setting is introduced. This is
specifically a sun-shadow update, not a claim that every retained particle or
post-processing feature now responds to all settings live.

## Tests

Godot 4.7.1 on macOS, isolated save directories:

| Check | Result | Log |
| --- | --- | --- |
| Final live-quality and real pause/settings/resume integration | 80 assertions passed | `/tmp/kras-live-shadow-ui-final.log` |
| Same final integration with actual Metal Mobile rendering | 80 assertions passed | `/tmp/kras-live-shadow-ui-mobile.log` |
| Existing party/progression suites | 4171 assertions passed | `/tmp/kras-live-shadow-party.log` |
| Final compilation | 350 scripts passed | `/tmp/kras-live-shadow-final-compile.log` |

The quality regression checks tier changes, saver on/off while paused, reset
defaults, authored lighting and physical arena identity, a single settings
listener and callback cleanup. The integration constructs an actual match,
opens its actual pause menu, emits the settings button action, toggles the
real settings-sheet CheckButton, closes the sheet and resumes the same match.
It uses controlled legal phase transitions and disabled fixture physics, not
natural gameplay or physical touchscreen input. Headless and rendered runs
are separate checks, neither proving iPhone battery life or temperature.

An initial integration-test attempt incorrectly assumed the label was child 0
of every option row. RTL layout correctly placed the CheckButton first.
That test aborted with script errors and teardown leaks in
`/tmp/kras-live-shadow-ui.log`; its partial success summary is rejected. The
corrected test finds the Label sibling independently of row direction. The
final runs passed completed-summary and script-error/leak log guards.

## Mobile Renderer Measurement

Before this shadow patch, parent source
`55f6afa8f211d7fc4a261a82b2b73965e18f5c90` was measured with the actual Mobile
rendering method on Apple M5, Metal 4.0. It was still macOS hardware and desktop
platform behavior, not an iPhone build. Command:

```sh
godot --path . --rendering-method mobile tests/perf.tscn -- \
  --games=tank_arena --prepare-resources \
  --test-data-dir=/tmp/kras-tank-mobile-initial-save
```

`/tmp/kras-tank-mobile-initial.log` (exit 0, runtime log guard passed):

- Four AI competitors moved; 10.00 actual simulated seconds and 902 live samples.
- Mean 10.00 ms (~100 FPS uncapped), p95 16.79 ms, worst 132.07 ms.
- Resource preparation 2798 ms; synchronous setup 3533 ms.
- Teardown returned to the baseline 50 nodes.

This differs from the slower Forward+ samples recorded in the previous
qualification document. Renderer-dependent behavior is therefore important
to investigate; this single sample does not establish a causal GPU bottleneck
or prove that this patch improves performance. Its p95 slightly exceeds the
60 FPS frame budget and its large worst-frame spike remains unacceptable for
a claim of uniformly smooth rendering. No iPhone, thermal or battery target
is marked achieved. Further CPU/render profiling and device QA remain open.

## Release State

This is a feature-branch review only. The previous four-peer tank run remains
failed, final-source network CI and device qualification remain required, and
there is no new Railway deployment, main merge, Distribution archive, upload
or App Store review submission from this change.
