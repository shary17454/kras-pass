# Physical player order in Arabic HUD

## Change and reproduction

Gameplay/test commit: `d57af067917273379f4d171e4ed97551415655df`.
Branch: `feature/kras-online-random-rotation`.

Rendered Arabic four-human fixtures showed HUD cards mirrored P4 to P1 while
touch regions and vehicle viewports retained P1 to P4. The outer card grid now
uses LTR physical slot order; each individual card explicitly retains the
locale direction. Player identities, scoring, teams and world positions did not
change. This is a two-line production change, not a global removal of RTL.

The regression covers Arabic/English at 1280x720 and 540x960, asserting slot
identity, localized name direction and increasing global card X coordinates.
Before the fix: 49 assertions passed, six Arabic ordering assertions failed.
After the fix: all 55 passed; strict runtime log guard passed.

## Qualification

- Godot 4.7.1.stable.official.a13da4feb, isolated writable test HOME.
- All 466 scripts compiled; strict compile guard passed.
- Full suite: 427842 assertions, 243.7 seconds, exit 0; strict tests guard passed.
- Four ERROR messages were inspected: one deliberate failed-save fixture and
  three deliberate router-recovery fixtures, not arbitrary runtime errors.
- A first full-suite invocation omitted the documented `--fixed-fps 60` option.
  It was intentionally stopped with SIGINT (exit 130), preserving its partial
  log. It is not counted as a passing suite. The completed run used that option
  with a separate test-data directory. This is not an FPS performance result.

Native rendered smoke: Metal 4 / Forward Mobile / Apple M5, eight captures,
zero automatic failures. All eight images were visually inspected: goal_guard,
tank_arena, zone_hold and boss_colossus, default arenas, Arabic, four human
slots, portrait and landscape. HUD cards match P1-P4 control order and localized
text remains RTL. Vehicle viewports retain row-major seat order. This covers
four games, not every game/map or human play session. Boss particles extend
behind touch regions; the ordering fix does not address that separate polish
observation. No physical iOS device, energy, thermal or sustained FPS proof.

## Source and retained evidence

Tested runtime: `/tmp/kras-ab04d37-qualified-2026-10-15`.
Source fingerprint before/after final qualification:
`4713d46e1be342fe50320ccad49cb71e9e020c632228581e3c31b3f525cdaf5b`.
This selected-source fingerprint excludes tests and many assets; it is not
archive attestation. Both changed files were separately byte-compared to the
checkout and their SHA-256 values matched:

- src/ui/match_hud.gd: `06749ecdbe651004c1c062254fe854cb6af5fe04b811e8a617f4ecf6b1afb5b5`
- tests/suites/test_hud_numeric_direction.gd: `840698dac826763ecd422778382e0d1ab76355fc672f1697d248ed73e783c71d`

No source/test changes overlapped qualification. The checkout fingerprint
command encountered a file-read ETIMEDOUT; the runtime fingerprint above is
not misrepresented as a successful full-checkout comparison.

Sibling evidence directory: `qualification-hud-slot-order-2026-10-15/`.
Contains red/green focused logs, compile/render/full logs, the interrupted
partial log, visual-report.json and eight synthetic screenshots; no private
player save was copied.

Full completed log SHA-256:
`19bf771b7f286d5a0b61f92be51d183a8e914957bfa1f1ff26d0b920929205a1`.
Rendered log SHA-256:
`0ccdb1f1ad9805949994da86a56dbea4f2c779f1bcb3a0e1b8fbb6d9744e4080`.

## Remaining gates

Stage 0 remains QA_PENDING/MERGE_PENDING. Known balance issues, full content
qualification, physical-device QA and production backup/restore authorization
remain unresolved. No merge/main push, Railway deployment, new signed archive,
upload or App Store review submission occurred in this qualification.
