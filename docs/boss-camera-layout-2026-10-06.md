# Boss Camera And Portrait HUD

Branch: `fix/kras-colossus-camera-visibility`, based on PR115.
Camera runtime: `901abce`.
Final HUD/visual runtime: `d98d495964aec6a6ef78c47aa92c13c00fe8d958`.

## Corrections

The Colossus central head hid the rear fighter in the ordinary arena view.
The controller now requests TOP_DOWN; that camera mode previously assigned
a pitch without adjusting its actual horizontal distance. Its distance now
matches the authored 78-degree overhead angle. Other camera modes and combat
physics are unchanged.

A camera regression checks the real boss head height, rear-spawn sightline,
safe-area framing and steep angle in both orientations. Before correction:
693 assertions passed, five failed. After: 698 pass.
`/tmp/kras-colossus-camera-{red,green}.stdout`.

Actual portrait rendering also exposed an existing HUD defect: wrapped boss
text could change its minimum height after the player-chip strip had already
been positioned. The old source's portrait screenshot exhibited the same
defect. Refit now follows the clock container's minimum-size change. Viewed
before/after images show chips returning to the top and the arena occupying
the gameplay region, instead of a tiny ring below a displaced scoreboard.

The visual harness now validates portrait boss HUD height and records
`hud_bottom`. Its audio shutdown uses the existing performance harness's
shutdown, two frames and 100-ms drain sequence. Explicit shutdown without
the drain still reproduced seven WAV/playback leaks; this is a harness exit
correction, not proof that every application audio lifetime is leak-free.

## Verified Evidence And Limits

- Full gate on CAMERA runtime 901abce: 366170 assertions in 274.4 seconds,
  390 scripts, zero structural issues, three-lap and six boss probes pass,
  117 stability matches with zero failures. Settled static memory
  133595152 bytes. `/tmp/kras-colossus-camera-release-gate.stdout`,
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.A6D6zE`.
- Final HUD focused suite: 165 assertions pass.
  `/tmp/kras-boss-hud-space-green.stdout`. The added space assertion also
  passed before the edit in that fixture; it did not reproduce the initial
  rendered lifecycle defect, so it is not a claimed red/green regression.
- Actual Colossus before/after native screenshots manually viewed.
  `/tmp/kras-colossus-camera-native-save/screenshots` and
  `/tmp/kras-colossus-camera-layout-save/screenshots`.
- Final Colossus render: two captures, zero failures, clean stdout guard.
  `/tmp/kras-colossus-camera-layout-final.stdout`.
- Independent final-source four-boss render: eight captures, zero failures,
  clean stdout guard, no WAV/playback leak warning.
  `/tmp/kras-boss-layout-confirm.stdout` and
  `/tmp/kras-boss-layout-confirm-save/visual-report.json`.

The first isolated native launch could not connect to macOS window services;
its owned process was explicitly terminated (143), not counted as a pass.
All subsequent rendered runs used the authorized local macOS session.

## Final-Source Requalification

The post-HUD source ee594016f1d25a93bd46f19a25b20060db04ad30 passed the
full gate: 366178 assertions, 117 stability matches, zero failures, and
192 server tests with six actual Godot world fixtures (none skipped).
Evidence: `/tmp/kras-boss-final-release-gate.stdout` and
`/tmp/kras-boss-final-server.stdout`.

Later gameplay captures revealed an independent Arabic numeric defect:
the correct current/maximum string `11 / 12` was visually reversed by the
inherited RTL paragraph direction. Only the numeric value label now uses
LTR direction; localized names, alignment and card placement are unchanged.
The regression failed before the edit (eight pass, one fail) and passed
after it (nine assertions). Native Goal Guard and race images were viewed
after the correction. Evidence: `/tmp/kras-hud-fraction-{red,green}.stdout`
and `/tmp/kras-hud-fraction-native-save/screenshots`.

Final runtime: `3e2c718ae647d23c7e052bef61c2a66b56e1f591`.
Its full gate passed 366186 assertions in 295.3 seconds; 391 scripts compile,
435 resources were audited with zero structural issues, race and boss probes
passed, and 117 stability matches had zero failures. Settled static memory
was 133595552 bytes, with the watched material/mesh/texture/audio caches
released. This is not a device memory, battery or thermal benchmark.
Evidence: `/tmp/kras-hud-final-release-gate.stdout` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.Gd4xwd`.
The final-source server run passed all 192 tests without skips using the six
world fixtures from that same gate: `/tmp/kras-hud-final-server.stdout`.

The native Metal Mobile renderer captured 78 final-source Arabic gameplay
images: all 39 default arenas in both orientations, one stationary touch
player and three medium bots, after three additional seconds of gameplay.
The stdout guard passed, with no shutdown resource-leak warning.
Evidence: `/tmp/kras-final-gameplay-all39.stdout` and
`/tmp/kras-final-gameplay-all39-save/visual-report.json`.
These automated captures do not certify every image manually, alternate
maps, all human-player combinations, sustained frame rate or physical iOS.

## Remaining Release Gates

A natural Colossus campaign on the equivalent combat runtime defeated the
boss in only 3 of 24 medium baseline matches. The simulator's empty balance
flags do not establish acceptable boss difficulty. A separate medium trace
also ended without defeating it; fair movement/approach and cooperative
winnability still need investigation before READY classification.
Evidence: `/tmp/kras-boss-final-natural-report/report.json` and
`/tmp/kras-colossus-medium-trace.stdout`.

Other maps, real-device touch, battery, thermal acceptance and current CI
remain pending. The production database backup audit was denied before
execution and awaits explicit user approval for a server-local temporary
copy with safety-summary-only output. No production database was copied.
No main merge, production deploy, signed archive, Apple upload or review
submission occurred. Final Apple build remains local Xcode 27, not Xcode
Cloud; identity/profile checks alone are not archive or release proof.
