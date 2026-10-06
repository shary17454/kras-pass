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

The full gate predates the final HUD edit. It MUST be rerun on final source
before integration/release; targeted post-edit checks do not replace it.
All-39 rendered requalification, later gameplay frames without the start
announcement, other maps, real-device touch, battery and thermal acceptance
remain pending. No main merge, production deploy, signed archive, Apple
upload or review submission occurred. Final Apple build remains local
Xcode 27, not Xcode Cloud.
