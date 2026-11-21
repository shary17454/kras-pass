# Responsive Match Header Qualification

Runtime source: `1a395874c14697e6cbac45637f1d596d1879178f`.
Branch: `fix/kras-responsive-match-header`.
Stacked draft PR: https://github.com/shary17454/kras-pass/pull/104
Base: `fix/kras-local-xcode-release-resources` (PR 103).
Neither change was automatically merged into main.

## Reproduction and Correction

The bundled font change made player cards and the role caption overlap in the
native portrait capture. A regression test reproduced the problem: 145 checks
passed and 32 failed before the correction, exit one.
Log: `/tmp/kras-responsive-header-red.log`.

The shared HUD now positions portrait cards below the measured clock, round,
caption and optional boss meter. Portrait uses one four-column row, omits the
3D thumbnails, and retains player names, symbols, score, crown, effects and
charge bar. Effects share the score row rather than increasing card height.
Landscape retains thumbnails and the central clock gap. Label changes trigger
layout updates; orientation changes restore the corresponding sizes. The
existing `text_scale` accessibility setting is preserved, including 1.6x.
No gameplay rules, player stats, AI, networking or scoring were changed.

## Focused Checks

Shared HUD suite: 3287 assertions passed, including ar/en, portrait/landscape,
rotation back to landscape, narrow portrait, long local names, four humans,
maximum text scale, active status replacement, and teardown node baselines.
Its catalog smoke test uses all 39 definitions with a shared HUD and no
minigame controller; it is not a simulation of all 39 gameplay states.
Log: `/tmp/kras-responsive-header-catalog.stdout`, runtime guard passed.

Bundled fonts: 843 assertions passed. Performance sampler: 15 passed.
Frozen-source boss health HUD: 157 passed. App lifecycle: 13 passed; both
runtime log guards passed. Logs: `/tmp/kras-responsive-header-boss-frozen.log`
and `/tmp/kras-responsive-header-lifecycle.log`.
All 388 scripts compile in the final source check.
Logs: `/tmp/kras-responsive-header-fonts.log`,
`/tmp/kras-responsive-header-perf-tests.log`,
`/tmp/kras-responsive-header-compile-final.log`.
The previous full 361897-assertion regression result belongs to `1242fd4`,
not this changed HUD source; a fresh full release qualification is still needed.

## Rendered Checks

Native macOS Metal mobile renderer, quality 2, cap 60, four Expert bots,
one displayed touch overlay (not a real human input test). Both frozen-source
runs completed 13 live seconds and all four players moved. Nodes returned
50 to 50 after teardown. Images were inspected and runtime guards passed.

| Capture | Output | Steady FPS | Worst Frame | RAM After |
| --- | --- | ---: | ---: | ---: |
| Portrait | 720 x 1280 | 57.41 | 346.532 ms | 120.86 MiB |
| Landscape | 1280 x 720 | 58.86 | 203.786 ms | 125.70 MiB |

Reports and images: `/tmp/kras-responsive-header-final-portrait.json`, `.png`,
and `/tmp/kras-responsive-header-final-landscape.json`, `.png`.
Landscape reports an internal live texture size of 854 x 480, so the saved
1280 x 720 image is not proof of native-resolution 3D throughput.

The role caption, chips and notification no longer overlap in these captures.
Portrait still crops part of the arena at the right edge, although the sampled
players remain visible. Camera framing, all-game rendered QA, actual touch and
gamepad sessions, physical phone/tablet FPS, heat and battery remain open.
The long frames above are not resolved performance issues.

## Release Boundary

No new iOS export, signed Archive, upload, processing or Apple review occurred
for this HUD source. The earlier local Xcode 27 Release compilation references
`1242fd4` and must not be relabeled as a build of this commit. Future builds
continue through local Xcode 27, not Xcode Cloud, after fixing remaining release
gates and selecting a new version/build from current App Store Connect state.
