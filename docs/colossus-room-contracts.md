# Colossus Development Room Contracts

## Scope

The development client and server now admit `boss_colossus` only on its authored
`vortex_ring` arena. There are 39 catalogue entries in the development room list.
This is not qualification of all 39 online games, production activation, or an
App Store release. The production endpoint/configuration has not been changed.

## Contracts Tested

- Invalid arena configuration is rejected.
- Only the host can publish world snapshots or results.
- Malformed boss phase, exposure, fist scale and crater IDs are rejected without
  replacing the last accepted snapshot.
- A disconnected guest resumes the same player identity and complete carved world.
- A disconnected host resumes the same identity and completed result.
- A tournament final resolves its champion without changing ordinary points or cups.
- Godot creates the shared match config, preserves contender slots, and retains
  the authored ordinary duration. The smoke fixture uses its short duration only
  for a tied final, not for ordinary boss qualification.

## Results

- `node --test rooms.test.js`: 58 passing tests, zero failures or skips.
- Godot client contracts: `/tmp/kras-colossus-room-config.log`, 92 assertions.
- Full Node suite with the actual Colossus capture: 114 passing tests, zero
  failures, five skipped capture tests (Armed Race, Siege, Forge, Dreadnought,
  Sovereign). Those five fixtures were not supplied in this run; it is not a
  complete cross-engine capture gate.

## Outstanding Qualification

- Add Colossus-specific input driving and observation gates to the real peer smoke.
- Require actual damage, slam, carved ground and ordinary boss defeat, not merely
  a timer result or manually reduced health.
- Run two/four-client ordinary matches, disconnect/resume, tournaments and tied finals.
- Complete the cross-engine capture gate and full Godot regression.
- Measure scheduling/load stalls and actual device performance before release.

No authored boss health, damage, attack timing or scoring was changed.
