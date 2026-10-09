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
