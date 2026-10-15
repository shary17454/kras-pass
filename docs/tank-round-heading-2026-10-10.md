# ATV round-start heading repair

Base checkout: `4376df2923d6bc4472558ef1417bfaaa2105ffa3`, branch
`feature/kras-online-random-rotation`. Runtime fingerprint after the fix:
`a6e844a59bf8df7945bc5a5edae0e5372d3595a914c54cf10fde47518a5e4ca8`.

## Reproduction and change

Turret Duel initializes every fighter facing the arena center at round start.
Tank Arena overrides that lifecycle method but previously called only cleanup,
so initial world-forward headings and previous-round headings survived instead
of using the shared initialization. The override now calls
`super.on_round_start()` and retains all existing inventory/armor resets.
The inherited cleanup still executes. No global character stats, AI skill,
damage, spawn positions or balance thresholds were changed.

The existing Tank network suite now checks all four player headings on round
start and after deliberately reversing them and starting another round.
Before the source correction it failed seven new assertions (185 passed).
After the correction all 192 assertions passed. This proves the lifecycle
defect and its repair, not that it alone explains the observed spawn win bias.

## Qualification

- Tank network/presentation/inventory/reset suite: 192 assertions passed.
- Tank crate-perception suite: 93 assertions passed.
- Driver-engagement suite: 37 assertions passed.
- Compile check: all 449 scripts passed.
- All successful logs passed the existing strict Godot log guard.
- Local qualifying processes ran sequentially on the isolated imported copy,
  with separate test-data roots, and exited zero before further source edits.

Raw failing and passing logs are retained at
`../qualification-tank-heading-2026-10-10/`.

The natural 96/48/2 samples in `expanded-balance-review-2026-10-10.md` predate
this runtime change. They remain historical evidence, not post-fix acceptance.
Core run `38015873710` succeeded on the previous runtime commit c46a7f1 and
must not be used to claim this correction passed complete CI. New-source Core,
network and natural balance qualification still need completion and inspection.

No stage is marked DONE, no game READY, and there is no main promotion,
production deployment, signed release archive, Apple upload or review submission
in this repair batch. Physical-device and production gates remain open.
