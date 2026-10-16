# Integrated Source Qualification

## Source and Test Scope

Repository `shary17454/kras-pass`, remote `origin`, tested branch `main`,
exact commit `049e66019a4a8a8c41e9bdbc2262505c1741234b`.
The checkout remained clean throughout these checks. Documentation added after
the checks does not change the tested runtime tree.

Godot: 4.7.1 official `a13da4feb`, macOS, headless, fixed simulation 60 FPS.
This fixed simulation setting is not evidence of rendered 60 FPS on iOS.

`GODOT_BIN=/opt/homebrew/bin/godot sh tools/check_party.sh` exited zero:

- Compilation: 367 scripts, no compile errors.
- Inventory: 407 resources, 21 autoloads, 27 routes, eight characters, zero issues.
- Full test runner: 359768 assertions passed in 233.0 seconds.
- Actual race regression: all four AI racers completed three laps; PASS.
- Colossus AI probes: seeds 345, 9614 and 172; PASS.
- Forge, dreadnought and sovereign AI probes: seed 9614; PASS.
- Stability: 39 minigames, one cycle, four AI players, zero failures.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.sTaq9m/`.
Each step has `.stdout` and `.log` files checked by the wrapper's log guard.
These are local isolated checks, not the 39-game Internet matrix, all-arena
visual QA, statistical character balance or full physical-device acceptance.

Server `npm test` initially passed 186 tests with six capture-dependent skips.
The six freshly generated files in `saves-tests` were then supplied through
`KRAS_ARMED_WORLD_FIXTURE`, `KRAS_COLOSSUS_WORLD_FIXTURE`,
`KRAS_FORGE_WORLD_FIXTURE`, `KRAS_SIEGE_WORLD_FIXTURE`,
`KRAS_DREADNOUGHT_WORLD_FIXTURE` and `KRAS_SOVEREIGN_WORLD_FIXTURE`.
That second invocation passed all 192 tests, zero failures and zero skips.
This verifies real engine/server capture contracts, not four Internet clients.

## Residual Memory Qualification

The font-only probe was rerun from the exact tested commit, with isolated saves:
`/tmp/kras-font-memory-049e660/font-memory.json` and
`/tmp/kras-font-memory-049e660.log`. Exit zero; runtime log guard passed.

Tracked static memory was 33475765 bytes at baseline, 59797861 with fourteen
bilingual labels alive, 59357189 after removing the labels while retaining
shared fonts, and 40232553 after releasing the idle shared fonts. Releasing the
fonts reclaimed 19124636 bytes in this sample. This does not attribute all
remaining memory, measure RSS/GPU usage or prove iOS memory safety.

The earlier same-commit optional post-games probe at
`/tmp/kras-font-after-games/stability.json` recorded 39 matches with zero
failures. After graphics cache release and five real seconds it retained
441294480 tracked bytes; releasing idle UI fonts reduced this to 424431540.
The watched cached paths remaining were 44 scripts. The census only covers
known match-preparation paths and is not exhaustive native allocation evidence.
About 405 MiB remained unassigned; fonts alone do not explain that remainder.
No production font cleanup behavior was changed for these measurements.

## Live Production Inspection

Railway is linked to `shary17454/kras-pass`, branch `main`, production service
`kras-pass`. The automatic deployment for the tested source is
`574f7937-8d0b-4875-829f-a356f2b6781d`. Repeated inspection still reported
`BUILDING`, with no running instance, an initial RAILPACK manifest and no
Dockerfile path. The tracked `railway.json` specifies DOCKERFILE; the effective
final manifest must be checked before qualification. No restart or duplicate
deployment was triggered merely because logs or observation were incomplete.

The previous deployment `1861cc16-5aa2-48a6-96c7-89ac8f108b7a` was SUCCESS,
with a running instance and source `8aabcd3346a1ba269bafb8b21a0ab92324ea2f4e`.
It used DOCKERFILE and `/health` with a 100-second healthcheck timeout.
The `/data` volume was READY. A fresh production `/health` probe returned
`ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`.
This proves the existing API responds, not completion of the new deployment.

## Release Gates Still Open

No new Apple archive, Distribution verification, upload, processing or review
submission occurred in these checks. The full goal remains unfinished.
Outstanding acceptance includes current production deployment and logs,
Internet multiplayer and reconnect/host-loss QA, all-game balance and readiness,
physical iPhone/iPad orientation, touch/gamepad, sustained performance, thermal
and battery testing, residual memory attribution, full replay qualification,
the remaining product requirements and exact-source Apple distribution gates.
