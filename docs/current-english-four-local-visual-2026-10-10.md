# Current English four-local-player visual qualification

## Source and coverage

Development checkout `689cc7b` includes runtime source
`5b07018a6358368a6cddc0f6ec68f2cd617df55d`. The isolated Godot 4.7.1 runtime
fingerprint before and after all captures is unchanged:
`c6997498a03697a4c59d66bb1cf99ef2016098bc982dcaf88ace346df6e1cf81`.

The existing rendered `tests/stage_zero_visual.tscn` ran with `--all-arenas`,
`--humans=4`, `--locale=en`, `--play-seconds=2`, and an isolated save directory.
All 39 games and 57 declared game/arena pairs produced the expected 114 unique
captures at 1280x720 and 540x960. These coverage keys exactly match the Arabic
campaign. This is idle automated touch-slot smoke coverage, not four actual
people playing or physical-device performance acceptance.

## Original result and focused repeat

The original process exited one: 112 captures passed, two failed:

- `symbol_echo-echo_hall/landscape`
- `mukharrib-paint_grid/portrait`

Each failed capture follows an `app backgrounded` log event and records
`paused:true` and `pause_menu_present:true`. Their arena identities, four
living actors, touch slots, control bounds, objective text and objective bounds
remain valid. The original failures are retained; the campaign is not described
as an uninterrupted 114/114 pass.

After the first process ended, the same unmodified runtime repeated those two
games with the same language, roster and additional-play settings. All four
captures across both orientations passed and the process exited zero. Both
output logs passed the strict engine-log guard. All originally failed coverage
keys have a passing focused-repeat capture; no assertions or auto-pause behavior
were disabled or weakened.

Actual images inspected: tank foundry in both orientations, goal guard landscape,
boss dreadnought in both orientations, sky causeway race portrait, repeated
symbol echo landscape and repeated mukharrib portrait. These sampled inspections
do not constitute manual approval of every screenshot or final art quality.

Original logs, report and screenshots are retained in
`../qualification-current-en-visual-2026-10-10/original/`; focused-repeat evidence
is in the sibling `repeat/` directory. Temporary originals:
`/tmp/kras-current-en-four-visual-save` and
`/tmp/kras-current-en-four-repeat-save`.

## Dependency advisory checks

At this source, `npm audit --omit=dev --json` in `server` and repository root,
and the root `npm audit --json` including development dependencies, all exited
zero and reported zero known vulnerabilities. No installation, package upgrade,
lockfile change, secret inspection or production operation occurred. Advisory
results are time-specific and do not prove complete application security.

## Remaining gates

Neither these desktop screenshots nor the earlier Arabic campaign certify
iPhone/iPad layout, real touch ergonomics, energy, heat, controller hardware,
Internet reconnect, or native App Store screenshots. No image was uploaded to
Apple. Current-source natural balance and network qualification, production
backup/restore approval and deployment, final local Xcode 27 signing/archive,
upload, processing and review submission remain separate unfinished gates.
No main push was retried and no stage was promoted to DONE or READY.
