# Forge Feeding Perception

Runtime tested: `9ab1ef13a713c3052e28e80b47bb26cb1fb02042`.
Branch `fix/kras-forge-observed-feeding`, based on the Colossus observation
patch, not merged into main or deployed to production.

## Fix

The boss hunter previously requested Forge's feeding plan using live crate and
slag positions, without visibility or acquisition delay. A controlled scene
with an actual hidden crate still produced an attack. The initial test exited
one: one assertion passed, two failed. Evidence:
`/tmp/kras-forge-observation-before.log`.

Forge now supplies the actual item nodes in separate crate and slag groups.
The hunter builds its plan from delayed visible observations, using the shared
camera/occlusion checks. Empty observations cannot fall back to live items.
Hidden/offscreen/removed items lose observation credit; round restart clears
both groups. The existing bounded 32-sample helper is reused by feeding and
weak-point acquisition instead of duplicating their observation logic.

The optional observed-data argument preserves the legacy single-argument
feeding interface. Hot-item priority, inward push geometry, damage, movement,
difficulty profiles and network schema are unchanged.

## Verification

- Focused feeding perception: 18 assertions passed, including actual hidden
  crate rejection, visible aligned attack, reaction threshold, delayed movement,
  slag priority, offscreen/removal handling, bounded history and round reset.
- Shared weak-point regression: 51 assertions passed after helper extraction.
- Full wrapper from the committed runtime exited zero: compilation 369 scripts,
  inventory 409 resources with zero issues, 359835 assertions in 186.9 seconds.
- Actual three-lap race and all six natural boss probes passed.
- Forge seed 9614 at Expert defeated the boss, scores [211,110,407,168].
- Single-cycle stability completed 39 matches, zero failures.

Focused logs: `/tmp/kras-forge-observation-bounded.log`,
`/tmp/kras-forge-weak-regression.log`. Full evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.hOBLy6/`.
The wrapper applies engine log guards to each step.

## Remaining Scope

These constructed scenes and selected natural probes do not establish
statistical balance, all-agent fair perception or physical rendered acceptance.
Partial mesh-only hiding/culling of compound body cues has not been qualified
by these fixtures. Other specialized agents, repeated natural balance samples,
physical-device touch/gamepad/orientation, sustained performance/thermal/battery,
Internet/reconnect and full replay/persistence acceptance remain required.

No main merge, Railway variable change, production deploy or Apple
archive/sign/upload/process/review submission was performed for this patch.
The full product and release goal remains unfinished.
