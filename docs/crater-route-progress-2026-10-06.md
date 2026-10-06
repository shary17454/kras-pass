# Crater Route Progress

Base: PR116, `40f4516db60f567f8e49af7b75a5a2ed954da6fa`.
Runtime: `fccd2a38beb32906249471b8c9aa9553cc02af78`.

## Proven Defect And Correction

The existing local safe-step selector passed a full detour around one crater.
With three overlapping radius-three craters, however, it remained on safe
ground without reaching the opposite target from either side. The red test
had seven passing assertions and two failing arrival assertions. This is a
navigation defect, not proof that it explains every missed boss attack.

Carved-floor navigation now obtains a waypoint from Godot's AStarGrid2D when
the direct segment is blocked. A half-metre grid is reused until terrain or
clearance changes. Solid cells include segment padding; start/end connectors
and selected waypoints are checked against the exact crater geometry.
Existing near-rim escape and final-input dash clearance remain unchanged.
No health, exposure duration, damage, reaction delay or character stat changed.
The regression now passes 16 assertions, including cache reuse/invalidation,
invalid endpoints and restored direct routes after reset.

## Verified Evidence

- Red: `/tmp/kras-crater-route-overlap-red.stdout`, seven pass, two fail.
- Green: `/tmp/kras-crater-route-final-focused.stdout`, 16 pass.
- Existing physical-floor suite: 75 pass;
  `/tmp/kras-crater-route-floor.stdout`.
- Existing Colossus approach/dash suite: 112 pass;
  `/tmp/kras-crater-route-approach.stdout`.
- Full gate: 392 scripts compile, 436 resources and zero structural issues,
  366201 assertions in 181.9 seconds, race/six boss probes pass,
  117 stability matches with zero failures. Settled static memory 133617588
  bytes, watched caches released. `/tmp/kras-crater-route-release-gate.stdout`
  and `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.kWV7pe`.
- Server: 192 tests pass, none skipped, using the six actual Godot world
  fixtures from the same full gate. `/tmp/kras-crater-route-server.stdout`.
- Native Metal Mobile: two Arabic Colossus captures after ten seconds of play,
  portrait/landscape, manually viewed; stdout guard passed without shutdown
  resource leaks. `/tmp/kras-crater-route-native.stdout` and
  `/tmp/kras-crater-route-native-save/visual-report.json`.

## Balance Remains Unqualified

The previously failed medium trace (seed609001, nabta/sakhra/fanoos/ramla)
defeated the boss after this edit. `/tmp/kras-crater-route-medium.stdout`.
That single success DOES NOT establish improved balance.

The matched natural campaign rotates all eight characters through the same
24 seeds (offset600000), medium difficulty, one round and the authored
150-second window, followed by 16 paired difficulty comparisons and two
mutator/chaos trials. Before: 3/24 baseline boss defeats, mean146.297 seconds.
After: 2/24, mean147.736 seconds; a `character advantage` flag appeared.
Expert paired share is 0.643678. The new navigation regression is fixed, but
the broader boss-winnability gate is still FAILED/NEEDS_BALANCE.
Reports: `/tmp/kras-boss-final-natural-report/report.json` and
`/tmp/kras-crater-route-natural-report/report.json`.

Do not classify this game READY from technical test success. Further evidence
must distinguish approach time, danger avoidance, missed exposure windows and
character contribution. Physical iOS controls, performance/battery/thermal,
other maps and full release gates are still unverified.
No main merge, Railway deployment, signed archive, Apple upload or App Review
submission is established by this work. Final iOS work uses local Xcode27,
not Xcode Cloud. PR116's completed CI covers its own head40f4516, not this
new runtime.
