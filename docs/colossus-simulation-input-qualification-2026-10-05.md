# Colossus network input timing qualification

## Scope

The online smoke peer previously selected Colossus attack pulses from wall time,
although fighter attack durations and fist exposure use physics time. The driver
now advances its 0.4-second pulse clock only in PLAYING or SUDDEN_DEATH, using
the physics delta. Other phases reset it. The existing 0.1-second attack pulse
and visible safe attack-plan requirement are unchanged.

No boss health, damage, exposure, round duration, reconnect deadline, production
gameplay, protocol, or actual-defeat assertion was changed. This is a test-driver
correction, not proof that the reported gameplay failure has been fixed.

## Source

Branch: `test/kras-colossus-simulation-input`.
Parent: `8c44a7c6f452b4c7d1acabacbb56cd2139c48ddb`.

## Verification

- `colossus_input_clock`: 9 assertions passed, exit 0.
  Log: `/tmp/kras-colossus-input-clock.log`.
- `colossus_approach`: 112 assertions passed, exit 0.
  Log: `/tmp/kras-colossus-approach-clock.log`.
- Both Godot invocations emitted a native macOS system-CA retrieval error at
  startup. Assertion success is not a claim of error-free engine logs.
- `git diff --check`: passed.
- A real WebSocket/Godot two-human plus two-bot smoke attempt with seed
  `716952317` failed, exit 1. The restricted invocation first failed to open
  loopback with EPERM. The permitted invocation started successfully but lost
  the host session during loading, before simulation: boss health remained 800,
  elapsed 0, snapshots 0. Reported maximum frame gaps were 56,314 and 65,630 ms;
  the service closed the room with `host_left`, followed by `session_expired`.
  Evidence directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Wk02FA`.

## Remaining Gates

The previous CI failure (run 37245701658) ended a natural fight with boss health
30, without actual defeat. This local attempt did not reach that state and does
not establish its cause or resolution. A complete seeded natural network run,
then four-human and tournament qualification, remains required. Do not lower
health, weaken actual-defeat checks, or extend watchdogs to claim success.

No merge into main, Railway deployment, device qualification, archive, upload,
or App Store review submission occurred as part of this change.
