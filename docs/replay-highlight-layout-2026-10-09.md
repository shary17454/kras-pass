# Replay Highlight And Transport Corrections

Parent commit: `c1ee03c685317268a308da40e9c29412820dd47d` on
`feature/kras-online-random-rotation`. This report documents the following
local source changes; it does not attest an uploaded Apple build.

## Shipping Corrections

- A tied first place no longer creates a `narrow_win` or winning `comeback`.
- The photo-finish marker uses two seconds at the recording's tick rate,
  rather than an unconditional 120 ticks. Short recordings still clamp to 0.
- Replay transport uses wrapping controls and wrapping caption/status labels.
  All playback, speed, restart, six highlight, HUD, camera and back buttons
  remain available. No replay format, score, physics or match rule changed.

## Evidence

Before the highlight fix, focused replay tests failed on the tied result and
30/120 Hz marker offsets: 76 passed, three failed. After correction plus the
tied-comeback regression, all 80 replay assertions passed, including real
ordinary and chaotic record/playback integration.

Before the transport fix, actual container layout failed viewport containment
for Arabic/English at both 540x960 and 1280x720: 581 passed, four failed.
After correction: 585 headless assertions passed. Actual Metal rendering on
Apple M5 passed 589 assertions and produced four screenshots. All four were
visually inspected. Tests include all six highlights, every control, 1.4 text
scale, viewport containment and pairwise button overlap checks.
These are the shipping transport widget mounted in a layout fixture, not
physical iPhone screenshots or a full match behind the widget.

Full Godot regression: 393578 assertions passed in 180.8 seconds, exit 0.
Compilation: all 433 scripts pass. Inventory: 535 resources, 22 autoloads,
27 routes, eight characters, zero structural issues. `git diff --check` and
the existing Godot log checker passed. Sandbox CA-certificate errors and
intentional negative-test warnings remain in raw logs; clean logs are not
claimed. No server JS or production service changed in this correction.

Evidence directory, relative to the workspace containing this checkout:
`../qualification-replay-polish-2026-10-09/` contains red/green, compile,
inventory, full regression and rendered logs plus four screenshots.

## Source And Release Gates

Post-change runtime fingerprint:
`47e9e3b611339e1994762951c1ce54f8b6efbcadf936b95a642fc8b4ba60df50`.
The c1-source balance/network campaigns and expanded samples retain their
original source fingerprint; none are relabeled as testing these later edits.
Live campaigns were not cancelled or restarted. This commit is kept local
until the current branch's network campaign terminates, to avoid its
cancel-in-progress push behavior.

No main merge, Railway deployment/database operation, device installation,
archive, upload, processing or App Review submission occurred. Whole-scope
content acceptance, current-source qualification, physical-device gameplay/
energy acceptance, production integration and an exact-source locally signed
Xcode 27 archive remain required before release.
