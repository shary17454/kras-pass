# Natural race recovery observation

## Change

Branch `test/kras-race-recovery-observation` is based on crate PR #49, not main.
Only the scripted input driver and CI fixture change. The previous outward
steering attempt lasted from simulated second 2 to second 5. Stall recovery
requires three seconds of sustained blocked driving after contact, so that
window could end before recovery began. The circuit also has physical barriers;
outward driving is not guaranteed to produce an off-road fall.

The driver now continues until recovery is actually observed, bounded by
simulated second 18, then follows checkpoints normally. It neither moves a
fighter directly nor invokes recovery methods. The strict recovery, boost,
lap completion, authority and result comparison assertions remain unchanged.
This can exercise real stall recovery, not exclusively a fall.

## Executed evidence

`node server/network-smoke.js --game=kart_sprint --humans=2 --seed=439903641`
passed. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-ywumxx`.
The source was crate commit 6c308b8 plus the driver change, before adding this
document and the CI seed fixture.

Both scripted human clients reconnected, finished both internal races with
three laps, and accepted identical scores `[4730,4171,1999996326,1999995716]`.
The guest accepted 1463 world snapshots. Two AI racers are also present, but
these scores do not establish that every Bot completed all laps.
The existing strict boost/recovery observation gates passed on host and guest.
Server event-loop maximum was 1556 ms; host frame gap reached 12020 ms.
This heavily delayed headless run is not device smoothness evidence.

- Godot kart network presentation: 121 assertions passed; log guard passed
  (`/tmp/kras-kart-recovery-network.log`).
- Compile: 335 scripts passed; log guard passed
  (`/tmp/kras-race-recovery-compile.log`).
- `git diff --check` passed after the driver change.

CI uses the failing seed for the existing kart ordinary-match command, which
still runs both two-human and four-human groups. It does not add a new process
group or extend any process/job timeout. Tournament and final tests remain.
The four-human seeded scenario and full Linux matrix are not yet qualified by
the local two-human result. Lab volley coverage, all release/device gates,
coordinated Railway deployment and Apple submission remain outstanding.
