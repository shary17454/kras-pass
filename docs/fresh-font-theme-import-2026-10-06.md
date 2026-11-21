# Fresh Checkout Font Theme Initialization

Runtime source: `0e091bec3374f23ec61ff1908c081a91baa5b4c0`.
Branch: `fix/kras-fresh-font-theme-import`, based on PR 109.

## Failure

PR 108's core and ring-network jobs in GitHub run `37409510505` failed during
the initial import, before tests. The project theme referenced five imported
fonts while `.godot/imported/*.fontdata` did not yet exist. The earlier
minimal fresh project reproduced the same missing-fontdata and theme errors.
Existing local caches hid the defect.

## Correction

`gui/theme/custom` now points to `assets/fonts/startup_theme.tres`, a Theme
without external imported dependencies. The first runtime autoload, `UITheme`,
loads the existing licensed bundled theme in `_enter_tree` and assigns its
font and size to the project theme before other autoloads or runtime controls.
The bundled font resource, shaping, explicit fallbacks and import parameters
are unchanged. Editor import does not execute this non-tool autoload.

ThemeDB's project theme is the intended global override mechanism:
https://docs.godotengine.org/en/stable/classes/class_themedb.html
No import error gate was weakened and no cached assets were committed.

## Verification

- Bundled font suite: 850 assertions passed, including inherited global font
  and Arabic/Latin/symbol/emoji coverage; `/tmp/kras-font-bootstrap-tests.stdout`.
- Status HUD: 3321 assertions passed;
  `/tmp/kras-font-bootstrap-status-hud.stdout`.
- Compilation: 389 scripts; `/tmp/kras-font-bootstrap-compile.stdout`.
- Memory diagnostic, emoji with default font primed: baseline 40,417,609 bytes,
  labels alive 51,426,117, final 51,155,233; no system-font cache clearing.
  `/tmp/kras-font-bootstrap-memory.stdout` and isolated save's
  `font-memory.json`. This measures static allocations in one headless process,
  not whole-device RAM, battery, heat or physical FPS.
- The first font test invocation omitted an explicit log path and crashed in
  engine startup after failure to open the sandboxed user log (exit 134).
  The rerun with `--log-file` completed normally. This is not evidence that
  every engine startup failure has been fixed.
- The initial HUD filter `match_hud` selected no suites and exited one;
  the completed check above uses the correct `status_toast_hud` filter.

## Clean Source Qualification

`git archive HEAD` generated `/tmp/kras-font-bootstrap-source.tar`, extracted
to `/tmp/kras-font-bootstrap-clean-source` without a `.godot` cache. Full import
completed with exit zero and passed the unchanged strict import log gate:
`/tmp/kras-font-bootstrap-clean-import.stdout`. The command ran locally with
macOS permissions required for Godot's editor data; no import errors were
excluded. Post-import runtime font checks on that source passed 850 assertions,
exit zero and the console gate: `/tmp/kras-font-bootstrap-clean-fonts.stdout`.
The generated bootstrap script UID is retained as metadata in the working
branch. Minimal corrected import earlier no longer reported font/theme errors
but had macOS sandbox write/CA errors; that minimal run was not a clean passing
import. The full source qualification above supersedes it for local import.

Native macOS Metal/Mobile render on that clean source, portrait 720x1280,
quality 2, 60 FPS cap, four Expert Bots and synthetic touch HUD, seed 72,
`tag_hunt` / `star_meadow`: 28.01 live seconds, 25.03 steady seconds, complete
duration and exit zero. Screenshot was inspected: Arabic text and symbols
render, controls are visible and the arena rim is within the viewport.
`/tmp/kras-font-bootstrap-clean-render.json`, `.png`, `.stdout` and `.log`.
Steady FPS 59.01, p95 18.594 ms, worst 145.805 ms, three frames above 100 ms;
setup 4008.065 ms. Nodes remained 51 to 51 after cleanup, static RAM peak
132.25 MiB, final 129.14 MiB. The console gate passed. This is a short desktop
observation, not an iPhone/iPad qualification or proof of no leaks/freezes.
Stalls/startup latency remain open; the font import fix does not claim to
resolve those. Do not discard the worse frame result in favor of prior runs.

## Boundaries

The full 365835-assertion run belongs to parent runtime `3132a061`, not this
change. Clean Linux CI and full post-change regression remain unverified.
All-game polish/balance, real multiplayer, physical iPhone/iPad acceptance,
production deployment and release-source/version checks remain required.
No main merge, signed local Xcode 27 Archive, upload, processing or Apple review
submission occurred. Do not use Xcode Cloud for the release.
