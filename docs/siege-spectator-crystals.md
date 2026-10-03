# Siege spectator-final scoring repair

Source fix: `9e2f4df` on `feature/kras-ci-source-evidence`.

The shared match lifecycle deactivates and hides noncontending fighters after
the Siege round starts, but the controller previously reset every roster
crystal to full health and solid collision. Final contenders could therefore
hit an excluded player's crystal and earn points without fighting a finalist.

The controlled regression `/tmp/kras-siege-spectators-before-valid.log` ended
with 115 passing and 12 failing assertions. It showed spectator crystals at
100 health with collision layer one, visible meshes, and an attack granting
one point. An earlier fixture mistakenly attempted ONLINE setup without room
state and raised a nil-context script error; its runner's 98-assertion success
line is not counted as a valid test run.

The repair uses authoritative `online_contenders` only for ONLINE context.
Excluded crystals reset to zero health, invisible meshes and zero collision,
without invoking destruction callbacks or adding points. Stable roster slots
and the existing world schema remain intact. Rams also reject zero-health
targets. Ordinary/offline rounds ignore stale online contender metadata and
restore all authored crystals and cover.

Final focused test `/tmp/kras-siege-spectators-final.log` passed 129 assertions.
It checks inactive spectator fighters, hidden/noncolliding crystals, rejected
attacks and an independently reset ram attempt, normal rival damage/points,
offline restoration, subsequent final reset, unchanged reset scores and JSON
acceptance of a real captured final state by the replica validator.
`/tmp/kras-siege-spectators-compile.log` compiled all 322 scripts successfully.
`git diff --check` passed. The local macOS CA retrieval warning is retained in
both logs; no GDScript/parse error occurred in these final invocations.

This is a controlled gameplay/replica test, not four independent online peers,
a full tournament, Internet/device QA or an App Store release. It changes no
damage amounts, cooldowns, match duration or ordinary tournament scoring.
Previously verified Linux runs target earlier source and cannot qualify this
new fix. Full regression and independent-process final qualification remain
necessary before final release integration. Production Railway still runs
`567c308`, which predates this client-side controller repair.
