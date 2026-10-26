# Menu readability repair - 2026-10-27

## Scope and source

UI-only repair based on integration source
`d796003a99e9528424fd715364a03c320e09b976`, in isolated checkout
`/tmp/kras-release-repair-20261026`, branch
`fix/kras-menu-readability-20261026`.

The original workspace files were preserved. Earlier uncommitted network
diagnostics in `tests/network_peer.gd` are not part of this UI change. No main
merge, Railway deployment, account migration, backup, signing or store operation
belongs to this repair.

## Reproduced defects

The Arabic portrait Adventure title split the single word into two fragments,
the progress strip overflowed horizontally, and the back button stretched to
the height of the broken title. A captured pre-fix render reproduced the user's
image. The old layout guard falsely passed because it only rejected controls
entirely outside the viewport, not partially clipped controls.

Expanded QA also found oversized or nonwrapping text in achievements, replay
empty state, the main menu, the boot screen, training and the character gallery.

## Changes

- Shared compact screen headings and vertically centered back buttons.
- Secondary header information placed in the scrollable body, not squeezed
  alongside the heading.
- Adventure world picker keeps all worlds and lock requirements, while exposing
  actual stages immediately. Stage cards keep objective, difficulty, stars and
  entry actions within the available width.
- Wrapped captions and responsive progress rows; removed fixed minimum widths
  that forced the phone layout wider than the viewport.
- Menu/grid buttons wrap; flow-toolbar buttons and single-symbol controls keep
  intrinsic widths. A global-wrap attempt failed the replay transport test and
  was replaced rather than weakening the test.
- Adaptive columns no longer reassign the same orientation on every resize.
- Ordinary character portraits use eight 512x512 images rendered from the
  original game models, instead of creating 3D worlds on menu entry. A recipe
  fingerprint includes shape, scale, colors and accessory; changed cosmetics
  keep the existing live-render fallback. Gameplay models and HUD are unchanged.
- Regenerate original portraits with `godot --path . tools/bake_menu_portraits.tscn`
  followed by the normal editor import. No third-party art was introduced.
- Layout QA now rejects partial horizontal clipping and records navigation and
  settle-frame timings. Timing is desktop diagnostic evidence, not iPhone FPS.

## Evidence

- New regression suite: 8,313 assertions passed across Arabic/English, 360x780,
  540x960 and 1280x720, and text scales 1.0/1.4.
- Replay transport: 585 assertions passed without relaxing visibility gates.
- Appearance regression: 1,151 assertions / 208 UI cases passed before the
  final boot/training/gallery caption additions; the final full run includes it.
- Complete unit/integration gate after caption repairs: 454,956 assertions
  passed in 435.1 seconds, with the strict Godot log guard passing as well.
- After the portrait optimization: 471 scripts compile; portrait resource,
  recipe-invalidation and nonblank-pixel checks passed with 57 assertions.
- Native portrait regression: 65 assertions, including the live customized
  fallback, passed its strict runtime log guard.
- Final native menu scan: 184 cases, zero partial-horizontal-clipping failures,
  nonblank captures for all cases, strict runtime log guard passed.
- Full unit/integration rerun including the portrait optimization: 455,012
  assertions passed in 526.9 seconds; process exit zero and strict log guard
  passed. Intentionally injected save/router/harness failures were handled by
  their existing negative-case policies, not counted as production errors.

Runtime/UI implementation commit: `7e3417728f438373ef12d4f27083f762f7633ff7`.
Review: `https://github.com/shary17454/kras-pass/pull/218`, targeting the
integration candidate rather than production main.

The native QA recorded first-entry settle-frame peaks of 328.470ms for Adventure
and 706.053ms for Tournament before baked portraits; the follow-up recorded
29.086ms and 18.464ms respectively. These are two desktop diagnostic runs with
cache/scheduling differences, not a controlled benchmark or device performance
claim. The resource test separately proves that baseline portraits create no
3D viewport. Some library frames still reached 62.855ms in the follow-up.

Logs are `/tmp/kras-menu-*-20261027.log`; rendered all-menu evidence is
`/tmp/kras-menu-portraits-layout-20261027/`. The earlier full runs were interrupted
after finding a transport regression or to include expanded caption repairs;
neither is reported as a successful complete run.

## Limitations

The pictured clipping is reproduced and repaired, but a device-only hang has not
been reproduced or profiled. No claim that all iPhone freezes, heat, battery or
frame-rate issues are fixed. A real iPhone/iPad Release run, scrolling, repeated
navigation, gameplay and device profiling remain required before release.
The paired phone query returned no installed app matching `com.shary.kraspass`
or a Kras/Arabic-title match, so no on-device performance claim is made. No app
was installed, removed, or replaced on that phone.
