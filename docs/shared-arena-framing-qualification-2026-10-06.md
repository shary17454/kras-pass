# Shared Arena Perspective Qualification

Runtime commit: `99b960bf5cee31eeff7bb9179c1635c97f062232`.
Branch: `fix/kras-shared-arena-framing`.
Parent: `fix/kras-responsive-match-header` (draft PR 104).
No automatic integration into main or Apple submission occurred.

## Correction

The shared perspective camera previously followed clustered players and cropped
the opposite playable rim in portrait. ARENA, TOP_DOWN and ISOMETRIC now fit
authored rim samples and live targets into the space between the measured HUD
and touch controls, preserving perspective rather than switching to orthographic.
WORLD, CHASE, RACE, COURT and shared-world branches are not changed.
Four bounded projection corrections adjust distance and screen-space centering.
The existing zoom heuristic remains; this is not a new absolute distance cap.

Interpolation is disabled at readiness, rather than waiting for processing.
Uninitialized projections are skipped and near-plane crossings are corrected
before unprojection. The rendered QA overlay now informs the camera that one
touch control region is actually displayed.

## Tests

- Initial reproduction: 528 passed, 55 failed (exit 1),
  `/tmp/kras-arena-frame-red.stdout`.
- Final camera suite: 691 assertions passed,
  `/tmp/kras-arena-frame-final.stdout` and `.log`; runtime guard passed.
  Tests cover translated circular/square arenas, clustered players, three shared
  modes, portrait/landscape, four-touch reservations, HUD clearance and falling
  WORLD subjects. They are not rendered QA of all 39 games.
- Dodger camera visibility: 19 passed,
  `/tmp/kras-arena-fit-dodger-final.log`; runtime guard passed.
  An earlier incorrect `--suite=test_dodger_camera_visibility` invocation selected
  no suites and failed; only the corrected invocation is counted.
- All 388 scripts compile: `/tmp/kras-arena-fit-compile.log`.
  Log guard allows the known sandbox system-CA lookup error, not gameplay errors.
- `git diff --check` passed. No full release regression was run on this source.

## Rendered Evidence

The first native experiment emitted projection errors and is not qualified:
`/tmp/kras-arena-fit-portrait.log`. Readiness/near-plane corrections above removed
these errors in the later runs. Frozen-runtime captures used Godot 4.7.1,
macOS Apple M5 Metal mobile renderer, quality 2, cap 60, four Expert bots and
one synthetic touch overlay. Both ran 13 live seconds, all bots moved, and node
counts returned 50 to 50. Images were visually inspected; log guards passed.

| Capture | Saved Size | Steady FPS | Worst Steady Frame | RAM After |
| --- | --- | ---: | ---: | ---: |
| Portrait | 720 x 1280 | 55.69 | 455.952 ms | 121.07 MiB |
| Landscape | 1280 x 720 | 58.03 | 276.447 ms | 125.90 MiB |

Reports, images and logs: `/tmp/kras-arena-fit-final-portrait` and
`/tmp/kras-arena-fit-final-landscape`, with `.json`, `.png` and `.log` suffixes.
Landscape live 3D texture was 854 x 480, not native saved resolution.
Small headless checks overlapped part of capture startup; these are framing
smoke tests, not controlled comparative performance benchmarks.
The arena rim is visible in both captures, but stalls remain unresolved.

## Remaining Release Gates

Actual phone/tablet touch sessions, all-game visual QA, a fresh full regression,
balance, online production activation and end-to-end reconnect, physical FPS,
battery/thermal tests, and current App Store identity/version/build verification
remain required. No iOS export, signed Archive, upload, processing or App Review
was performed for this commit. The earlier local Xcode build is different source.
The release path remains local Xcode 27, not Xcode Cloud.
