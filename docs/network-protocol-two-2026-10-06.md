# Multiplayer Snapshot Protocol 2

Runtime source: `bf452364d67a284f0537573eb7edb181114cff00`.
Branch: `fix/kras-network-protocol-compatibility`.
Parent: `balance/kras-colossus-contestable-opening`.

The expanded Colossus snapshot exposure bound is incompatible with old guest
validators. Server and Godot transport now use protocol2. The hello check
accepts only an exact numeric revision, including JSON numeric floats; it
rejects strings, booleans, fractional values, missing and old/newer revisions.
The server rejects incompatible create/join/resume operations before room,
session, membership or token-holder connection mutation. Other clients cannot
bypass this by sending an old protocol in later operations.

Tests explicitly pin the revision to2; fixtures otherwise import the server
constant to avoid obsolete hardcoded success paths. A real WebSocket client
receives hello2, attempts create1, receives version_mismatch, and verifies no
room was created before proceeding through the valid four-client flow.

Evidence:
- Godot network suite: 202 assertions pass.
- Server full suite before the additional WebSocket assertion: 193 passed,
  zero failed/skipped, including six real Godot world fixtures.
- Final rooms suite after the WebSocket assertion: 59 passed, zero failed.
  `/tmp/kras-protocol-two-rooms-final.stdout`.
- Real Godot/network smoke passes 2-human/2-bot and 4-human sessions, matching
  final results and guest reconnect. `/tmp/kras-protocol-two-smoke.stdout`;
  detailed clients under the evidence directory printed in that log.
- Full Godot compile/resource/test/boss/stability gate completed with exit0.
  `/tmp/kras-protocol-two-gate.stdout` and its printed evidence directory.

Maximum local server loop delay was159ms while the full Godot gate ran in
parallel. This is not a sustained performance or internet-latency acceptance.
Physical iOS, production Railway and mixed-version error presentation remain
unverified. On incompatible hello, the existing transport closes without
sending pending membership requests. The existing Net service shows generic
unavailability; a retained reconnect token can cause bounded retries for30s.
An explicit localized update-required message and terminal mismatch handling
are still desirable UX work, not a claim of completed deployment.

## Coordinated Rollout

This deliberately breaks protocol1 online compatibility; local/offline play
is unchanged. Deploy protocol2 server before enabling online in the new app,
and keep online disabled until production checks pass. Old clients must not
join protocol2 sessions. No fallback permits mixing snapshot schemas.
Existing rooms are in-memory; server restart coordination must account for
active rooms rather than claiming reconnect survives a process restart.

No main merge, production deployment, signed iOS archive, upload or Apple
review submission occurred. Future iOS builds must use local Xcode27 and a
new build number from frozen, verified integrated source.
