# Remote-only tank final regression

## Recorded failure

GitHub run 37870776839, source ee8470df362d0bd1936ef94e41f373086b4c1b0c,
failed in the ordinary four-human tournament, before the older final checkpoints.
The preceding scores were [475,475,450,500], [475,500,475,500],
and [425,465,465,440]. Points were [6,11,7,11]; contenders were slots 1 and 3.
The host (slot 0) and slot 2 were spectators. Final: tank_oasis,
seed 1037876078, scores [100,500,200,500]. Shot and inventory observations were
true, armor damage observation false. The hit assertion remains mandatory.

## Reproduction

The new --tank-remote-final-checkpoint restores only preceding tournament
results. It runs the final with four real Godot processes, normal input,
pickup and projectile code, spectator checks and reconnect checks.
It does not inject final damage, scores, armor or a champion.

Command from server/:

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot node network-smoke.js --game=tank_arena --tournament --humans=4 --tank-remote-final-checkpoint
```

Local second run evidence:
/private/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-gY3vq3

It reproduced the original failure: true false true, scores [100,500,200,500].
Server loop maximum was 26 ms; a client reported 682 ms maximum frame gap.
Those timings do not by themselves establish the cause. Positions and routes
show movement along opposing road branches and shots without observed damage.

First run evidence:
/private/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-VIPBCv

It achieved real damage and results [100,450,200,453], but the newly introduced
driver initially compared points with the older host/bot checkpoint and failed.
The driver now checks this fixture's recorded [6,11,7,11] points and [1,3]
contender set. Do not count the first driver run as a passing qualification.
Variation across runs is evidence that seed alone is not deterministic across
real-time network input scheduling. Root cause is not yet established.

## Changes and checks

- Added the recorded remote-only final fixture and CLI selector.
- Added five passing Node checkpoint tests, including no-hit tie preservation.
- Added the fixture before ordinary tank CI matches so later failures cannot
  prevent this recorded regression from running.
- JavaScript syntax, workflow YAML and git diff whitespace checks pass.
- No shipping runtime, final duration, hit assertion or production state changed.
- Release gate remains OPEN/FAILED; this is diagnosis, not a gameplay fix.

## Test-pilot correction

The synthetic human driver pursued moving rivals along opposite road branches
and fired whenever its facing aligned, without requiring a clear path. It did
not hold an engagement distance. The revised pilot approaches the arena center
when the rival is distant or covered, still routes around actual collision
geometry, and holds throttle only when aligned within 12 units on a clear path.
It only requests shots with a clear path. This changes test inputs, not vehicle
physics, damage, ammo, spawn, final duration, collision or win conditions.

Two local four-engine checkpoint runs passed:

- /private/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-o8zOoB
- /private/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-9YnNVw

Both produced [100,478,200,465], champion slot 1, matching tournament results
across all four peers; host and one client reconnected. The first host trace
records armor [100,78,100,65], proving real damage. All eight individual stdout
files passed the strict Godot log guard. The network unit suite passed 410
assertions, including seven pilot checks. An initial sandbox launch crashed
while opening user://logs; the explicit local log-file run passed. Do not
discard that environment failure or report the isolated run as successful.

The original failing pilot traces remain retained. Two synthetic successes do
not prove player experience, AI balance, all maps, mobile performance or
production connectivity. Current CI must qualify this test change; release
is still not approved. The runtime source is unchanged.
