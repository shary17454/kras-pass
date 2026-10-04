# Tank observation steering qualification

## Source and scope

Branch `fix/kras-tank-observation-steering` starts from combined source
`9ef106f39b993f82950338e2213c6ea535675752`. This is a scoped Tank AI repair,
not a completed release, general AI certification or resolution of every
network smoke failure. No main merge, production deployment or Apple upload.

## Reproduced defects and repair

- `decide()` receives a physics-step delta but runs only on the decision
  clock. Subtracting that delta once per decision made a nominal one-second
  route refresh take many simulation seconds. Refresh now uses the shared
  simulation time, still with a one-second cache to avoid per-frame AStar.
- The previous loop retained the final road point after arrival. Reaching it
  now continues toward the already-observed rival; no hidden position query
  was added.
- With no visible rival or visible ammunition, the branch returned without
  replacing old driving input. It now searches the known arena center. At
  the center, the existing movement controller clears the old input.
- Round start resets the cached route and refresh deadline along with the
  shared brain's input/perception reset.

Speed, armor, damage, firing, observation filters and projectile/network
authority are unchanged. This does not promise complete navigation around
every obstruction or balance of all characters and arenas.

## Focused evidence

The added regression first failed against the original runtime:
159 passed and four failed in `/tmp/kras-tank-steering-before.log`.
Failures were refresh count, final-waypoint arrival, observation loss and
stale driving input. The geometry/clock test uses a controlled routing graph
and rival prediction; it does not represent a naturally played match.

Final source, including round reset checks:

| Check | Result | Log |
| --- | --- | --- |
| Tank network/presentation and steering | 165 assertions passed | `/tmp/kras-tank-steering-final.log` |
| AI visible targets | 2085 assertions passed | `/tmp/kras-tank-steering-visibility.log` |
| AI world occlusion | 18 assertions passed | `/tmp/kras-tank-steering-occlusion.log` |
| Script compilation | 335 scripts passed | `/tmp/kras-tank-steering-compile.log` |

Each test uses its own explicit `/tmp` save directory. The macOS headless
system-CA warning remains a baseline environment warning, not a new script
failure or evidence of successful Internet connectivity.

## Independent network evidence before this repair

The unchanged `9ef106f` source completed the two-scripted-client/two-Bot
Tank tournament with seed `870956740`, visiting `tank_oasis`, `tank_foundry`
and `tank_frost`. Both clients reported three completed matches, matching
final scores `[500,475,500,460]`, points `[9,6,13,5]`, champion slot two,
guest world snapshots 2567 and successful reconnect. Evidence directory:
`kras-network-smoke-uR2MF9` in the session's macOS temporary directory.

This did not reproduce the earlier Linux `tank_oasis` failure and must not
be called its resolution. The prior CI used a different seed sequence,
source/platform and timing. PR #42 run `37174083976` also failed pickup
evidence in Fawda, rescue evidence in Kart Sprint and actual Colossus defeat.
These remain open qualification gates.

Performance is not approved: this tournament reported a 2265 ms server
event-loop maximum and a 32255 ms host frame gap. The cause is unestablished.
Successful score synchronization does not prove smooth gameplay, phone
performance, thermal/battery behavior or four real Internet players.

## Remaining gates

The completed 29907-assertion / 117-match core campaign and existing iOS
export/development-signed QA app belong to `9ef106f`, not this new runtime.
Combined-source CI run `37196498325` also targets `9ef106f`. A new source
commit requires its own qualification and fresh iOS export/archive before
distribution; do not reuse the previous QA app as the latest source.

Full current-source core/network qualification, matched natural Tank balance,
four-player/device/Internet sessions, all outstanding product requirements,
production enablement and App Store release gates remain incomplete.
