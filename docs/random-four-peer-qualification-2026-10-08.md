# Independent Random Rotation: Four Actual Peers

The application source was `03b9a685c4926b2486dad8e46e64aa6d61fb1541`,
with the accompanying uncommitted test-harness additions in
`server/network-smoke.js` and `tests/network_peer.gd`.
Runtime/content/tool fingerprint was
`fe63142d531da9dd563b39d78f73fce0dc2b2b604a4f0c24e8436dc71f75914b`.
This run predates the subsequent DriverBrain braking change.

Command, from `server/`:

```sh
node network-smoke.js --game=ring_rumble --tournament --humans=4 --rotation=random --seed=17
```

Four Godot processes connected to a real local WebSocket server. All moved.
The host and one client disconnected and reconnected. All four reported the
same rotation policy, six completed matches, standings, and arena history:

```text
vortex_ring, storm_ring, vortex_ring, vortex_ring, storm_ring, vortex_ring
```

The consecutive repeat distinguishes independent random selection from the
no-repeat bag. The tournament completed after three regular rounds and three
tied deciders with four co-champions. This is not evidence of a unique sudden
death winner. Every peer stdout passed `tools/check_godot_log.sh`.

Evidence is retained in `docs/qa/random-four-peer-2026-10-08/`.
Inputs were scripted, transport was loopback, and no production credentials
were used. This does not certify four-person touch ergonomics, Internet
latency, production availability, iPhone performance, or App Store release.
Mixed-minigame online playlist selection remains a separate open requirement.
