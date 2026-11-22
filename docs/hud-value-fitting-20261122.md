# HUD Value Fitting

Base: `9ed976bae6350dde8996144fc17e256e53b68270`.
Branch: `fix/hud-value-fitting-20261122`.
This patch is uncommitted and changes HUD presentation only.

## Current Cache Freeze

The current source supersedes the pre-cache results below. `cache-focused-03`
passed 753385 assertions, including the unchanged 8960-case runtime matrix.
The `cache-affected-*` runs passed 1569/55/3585/769 assertions. All five runs
have exit 0, strict runtime/tests guards 0, no diagnostics/leaks, and identical
before/after source manifests. The manifest fingerprint for this freeze is
`e49184b9583f36c059700e6a6e18a8e4322e179170aeabfb39780816ffeeeb6e`.

The value-fit cache key is actual text, allocated width, preferred size,
accessibility-scaled minimum, font resource, and currently applied fitted size.
An unchanged refresh returns before tokenization or font metrics. A Font.changed
subscription is deduplicated per Font/HUD and conservatively clears all four
caches for in-place edits. The HUD owns no bound Dictionary callback cycle;
subscriptions disappear on HUD destruction. Old observed fonts can invalidate
conservatively until HUD destruction, but never allow a stale fit.

Tests verify 100 repeated cache hits, actual HUD refresh reuse, text/width/
preferred/minimum/font-resource/current-size invalidation, in-place resource
changes, zero unallocated width, restoration of the preferred size on growth,
and signal cleanup. An independent ascending metric oracle checks every unit
result and asserts whole numeric tokens really fit.

`cache-focused-01` is preserved as failed (one bad zero-width fixture assumption,
duplicate subscriptions and leaked callback references). `cache-focused-02`
passed its assertions but failed the runtime guard for duplicate subscriptions;
it is not qualification evidence. The one-subscription-per-Font/HUD implementation
in attempt 03 removes those diagnostics without weakening matrix assertions.

The optional native fixture now sets only its own window title to
`KRAS PASS HUD QA pid=<process id>` when `--hud-value-capture` is present and
restores the previous title at suite completion. Each capture waits up to
60 seconds using monotonic wall time for focus AND !Platform.is_backgrounded,
then fails without a PNG on timeout; it rechecks foreground after frame draw.
There is no focus override or app activation. The external native wrapper timeout
is 600 seconds to accommodate eight independent 60-second waits. No native run
of this updated fixture has been started; parent must coordinate/focus that
specific QA window, never the unrelated GodotUI PID 13560.

The current freeze report is outside Git at
`qualification-quickplay-20261122/hud-value-fitting-20261122/CACHE-FREEZE.md`.

## Reproduction

The existing Value label clips its single line while sharing an HBox with
effect glyphs. The focused fixture instantiates the real MatchHUD, Duel Pit
controller, Fighter values and PowerUpSystem effect query; no mock label or
replacement HUD value formatter is involved. It does not run match physics.

Actual runtime measurements, English, four players/one human, stock 3,
damage 13, scale 1, no safe inset, three registered effects:

| Window | Original allocated/text width | Patched allocated/text width | Patched lines |
| --- | --- | --- | --- |
| 540x960 | 84 / 97 | 137 / 97 | 1 |
| 1280x720 | 52 / 129 | 122 / 129 | 2 |

The portrait no-effect control fits (131 / 97); one effect fits (123 / 97).
Thus this is not a claim that every portrait 13% value is truncated. The
22-effect case is explicitly UI stress, not a claim about ordinary gameplay.

## Fix

- Value has its own stable width; effects use a separate wrapping HFlow row.
- Keep the original orientation-specific preferred font sizes and LTR digits.
- Use the actual Font metrics to fit individual tokens, with a 14 * text_scale
  reading floor; wrap between stock and percent rather than shrinking the
  whole line according to viewport width. Wrapped content receives height.
- Refit after actual allocation, orientation/scale fitting and value updates.
- No scoring, input, timing, balancing, controller or physics edits.

## Pre-Cache Focused Verification

`test_hud_value_fitting` has 8960 runtime cases: ar/en; actual rosters 1-4;
four-player rosters with human counts 1-4; long identities; text scale 1/1.6;
540x960/1280x720; full and inset safe areas; stocks 0/3/13/100/999;
damage 0/13/100/999; 0/1/3/22 effects independently of damage.
Assertions preserve controller text, complete numeric tokens, all visible
lines, reading floor, chip/safe bounds, identity/effect separation, and value
width stability as effects change. The default matrix is not skipped.

Artifacts outside Git:
`qualification-quickplay-20261122/hud-value-fitting-20261122/`.

- `red-final-rosters-05`: 657753 pass / 95530 fail, exit 1, no engine diagnostics.
- `green-final-capture-scope-07`: 753283 pass, exit 0, strict runtime/tests guards 0.
- Existing focused suites: value_text_fit 1569, numeric_direction 55,
  player_name_fit 3585, siege_hud_text_fit 769; all exit/guards 0.
- Those four suites used the same production bytes as final GREEN. Their
  test-file fingerprint predates only the optional native capture selector;
  no default assertions were removed. Every run preserved its source hashes.

Run only the focused suite, with a fresh absolute test data directory:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 \
  --path /private/tmp/kras-hud-value-fitting-20261122 \
  tests/test_runner.tscn -- --suite=hud_value_fitting \
  --test-data-dir=/private/tmp/unique-hud-value-test-profile
```

## Native Gate Still Blocked

`red-native-02` started Metal 4 Forward+ on Apple M5 but the actual test window
failed the foreground/focus guard. No fresh PNGs were accepted. The owned PID
58261 was terminated (SIGTERM); terminal and guards are preserved. Do not
claim native-after/GPU acceptance for this patch or reuse the parent's 9ed UI
images as after evidence. Historical before images were inspected: h1-en
portrait without effects shows 13% intact, consistent with the numeric control.

The optional `--hud-value-capture` selects eight explicit native presentations
(ar/en x humans1/4 with four players x both orientations, stock3/damage13 and
three effects). It retains the same fitting/bounds assertions for each selected
presentation and requires a real focused foreground window. This optional
capture selector has not passed native verification. No guard bypass is allowed.
No full suite, commit, push, merge, or physical-device claim was made in that capture attempt.

## Reviewed Cache Follow-Up

The final focused source adds a per-chip fit cache keyed by text, actual width,
preferred/minimum size, font resource and applied size. A single Font.changed
subscription per font/HUD invalidates cached metrics on in-place font changes.
Stable refreshes return before splitting or measuring the value again.

`cache-focused-03` passed **753385 assertions** with exit0 and both strict guards0.
The unchanged 8960-case matrix includes accessibility scale, safe areas, long
names and effect counts. The four affected HUD regressions passed 1569, 55,
3585 and 769 assertions respectively on the same frozen production source.
Cache invalidation and stable-hit tests supplement, rather than replace, the
layout matrix. All failed earlier attempts remain in the evidence directory.

The native-only fixture now uses `KRAS PASS HUD QA pid=<PID>` and waits at most
60 real seconds for genuine foreground/focus per presentation, rechecking after
draw before saving. It restores the previous title afterward. No activation or
foreground bypass is implemented. The Mac was separately observed locked by
the parent through Computer Use; new native capture awaits manual unlock.

Latest local evidence: `qualification-quickplay-20261122/hud-value-fitting-20261122/CACHE-FREEZE.md`.
This evidence is outside Git and does not claim physical-device or native-after
acceptance. A combined-source full regression and visual/device qualification
remain release gates after integration.
