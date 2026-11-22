# Protocol-two ruleset isolation

This integration branch is based on ff0f9aa, not the qualified BaseSiege
revision-two source. It adds network compatibility gates only. Do not deploy
this branch as atomic-v2 until it is integrated with the qualified Base2 source.
No replay, simulation, input, snapshot or host-authority implementation is
changed by this patch.

## Contract

- Wire protocol remains 2. Replay COMBAT_REVISION is not a network handshake.
- RoomClient.ONLINE_RULESET_ID is the immutable compiled session label
  `atomic-v2`; send() overwrites any caller-supplied ruleset on every message,
  including reconnect. It is not a fingerprint or proof of a client's binary.
- A protocol-two server advertises ruleset_version=1. The new client refuses a
  server without that capability, rather than allowing an old server to ignore
  the label silently. New clients validate welcome, room, start and public rows.
- Missing protocol-two declarations normalize to `legacy`. Explicit `legacy`
  is equivalent. Existing clients still create, discover, join and reconnect
  legacy rooms; their tokens and grace period are not invalidated by this gate.
- Declarations are bounded lower-case labels (1..64 characters), allowing later
  independently versioned rulesets without changing the wire protocol.
- The server binds a connection on its first valid declaration and freezes the
  room and player identities. Further messages may not change or omit an atomic
  declaration. Configure cannot overwrite room identity.
- Public lists are filtered before the limit is applied. Incompatible private
  codes return room_unavailable, like unavailable codes. A resume from the wrong
  ruleset returns session_expired for both known and unknown tokens, before
  disclosing active/expired membership. No token or ruleset is echoed in errors.
- Start checks every member/connection before roster mutation or seed use;
  beginRound rechecks this for tournament advancement. Room and start envelopes
  carry the pinned identity. A restored connection must match the retained
  player and room, and receives the same identity and epoch.
- Protocol one keeps its original envelopes and behavior. Host migration remains
  unsupported: host leave/expiry closes the room; it never promotes a guest.

## Future combat three

The integrated compound-budget revision three must use a NEW ONLINE_RULESET_ID,
not atomic-v2. Declare that identity before measurement/deployment and retain
atomic2/3 create/list/private-join/start/reconnect tests in both directions.
Do not use build numbers or a replay revision bump as substitutes for this gate.

## Verification boundaries

Node ruleset tests exercise the real Rooms implementation and WebSocket transport,
legacy and declared sessions, malformed/missing identities, filtering, safe
private errors, token reconnect and host-only authority. Node source-contract
checks are not Godot execution evidence. The focused Godot network suites are
registered separately and must run on frozen source when a headless slot is
allocated. No full catalogue, deployed service, physical device or mixed Store
binary compatibility is established by these tests.
