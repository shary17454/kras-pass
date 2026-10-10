# Current four-local-player visual qualification

## Source and scope

- Git source: `5b07018a6358368a6cddc0f6ec68f2cd617df55d`, branch
  `feature/kras-online-random-rotation`.
- Runtime fingerprint before and after the campaign:
  `c6997498a03697a4c59d66bb1cf99ef2016098bc982dcaf88ace346df6e1cf81`.
- Godot 4.7.1, rendered macOS test runtime `/tmp/kras-tank-pursuit-check`.
- Arabic, four human touch-input slots, no AI, all 39 registered games and
  all 57 declared game/arena pairs, landscape and portrait.
- Each capture includes two additional play seconds. Actors receive no human
  interaction during this smoke test; this is not four-person gameplay QA.

## Original campaign and retained failure

The campaign produced all 114 expected captures: 113 passed and one failed.
The last `duo_clash-bumper_bowl/portrait` capture was paused following the
`[DBG][Platform] app backgrounded` event. Its pause menu was visible; control
bounds, objective bounds, arena identity and four living actors remained valid.
The failure is retained, not converted into an original all-green result.

- Report: `/tmp/kras-current-ar-four-visual-save/visual-report.json`.
- Output: `/tmp/kras-current-ar-four-visual.stdout`.
- Engine log: `/tmp/kras-current-ar-four-visual-engine.log`.
- Screenshots: `/tmp/kras-current-ar-four-visual-save/screenshots/`.

Both the original output and the repeat output passed `check_godot_log.sh`.
This guard result does not erase the original paused-capture failure.

## Focused repeat

After the original process ended, the same unmodified runtime repeated
`duo_clash`, both declared arenas, both orientations, with identical roster,
language and additional-play settings. All four captures passed; the process
exited zero. The repeated bumper-bowl portrait image was also inspected.

- Report: `/tmp/kras-current-ar-four-duo-repeat-save/visual-report.json`.
- Output: `/tmp/kras-current-ar-four-duo-repeat.stdout`.
- Engine log: `/tmp/kras-current-ar-four-duo-repeat-engine.log`.

Representative actual images inspected: tank foundry in both orientations,
AlUla race landscape, goal guard portrait, quick draw portrait, and both the
original paused and repeated unpaused bumper-bowl portrait captures. These are
sampled human inspections, not manual approval of all 114 images.

## Unfinished release gates

This does not qualify physical iPhone performance, battery, four real players,
complete natural matches, production online play, or all content as READY.
The separate network campaign `38022898755` remains on its captured source
`c0a5b6c6d3b9cb0875c47aa9c87c5ada1ce39b9c`, not this newer runtime.

The requested combined Git command was rejected before execution by the
permission reviewer: promoting 434 commits to production `main` can deploy
Railway and trigger account-schema migrations before production backup and
restore acceptance. No main push, production migration, Apple upload or review
submission occurred. This report changes no runtime or test assertions.
