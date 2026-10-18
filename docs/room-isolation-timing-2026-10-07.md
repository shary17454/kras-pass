# Isolated Room Transport Timing

Tested commit: dffeb06dc1c82ff57be9c7889e2f728f9d9df2f3.
Runtime remains 3f1823a; no server behavior was changed for this measurement.
Command: node /tmp/kras-room-isolation.mjs. Exit 0.
Raw measurements: room-isolation-timing-2026-10-07.json.
Reproduction command: node docs/room-isolation-timing-2026-10-07.mjs
after installing the locked server dependencies.

One loopback room, four synthetic Node WebSocket clients, no Godot processes
created by this test. Three guests sent inputs at nominal 30 Hz; the host sent
627-byte synthetic ring snapshots at nominal 20 Hz for 30 seconds. Client and
server shared a Node process, so latency includes local scheduling and JSON
processing, not Internet or separate-process transport costs.

All 2688 guest inputs reached the host. All 593 snapshots reached all three
guests (1779 deliveries). No protocol errors. Input p99 latency 1.183 ms,
snapshot p99 latency 1.347 ms. Event-loop maximum 31.179 ms, p99 11.715 ms.
Process CPU 697.404 ms over 30.204 seconds. The 100 ms timing sampler observed
no interval overdue by 100 ms or more.

A second execution using the checked-in relative-path script also exited 0:
2673 inputs and 1767 snapshot deliveries, no errors. Maximum event-loop delay
was 82.248 ms, input p99 4.771 ms and snapshot p99 7.168 ms. Process CPU was
1008.596 ms over 30.207 seconds. The worse repeat is retained in
room-isolation-timing-repeat-2026-10-07.json, not replaced by the faster first
result. Four NetworkTiming unit tests also passed; node --check passed.

This narrows the investigation: this small four-client transport workload did
not reproduce the earlier 406 ms delay. It does not establish the cause of
that delay, prove performance with larger world payloads, exercise reconnect
under load, qualify production capacity, or establish phone frame pacing.
The actual Godot tournament result and its slow timing remain retained in
blast-network-tournament-2026-10-07.md; neither result supersedes the other.

The diagnostic script is retained alongside this report for reproducibility.
It binds only 127.0.0.1, uses the source checkout's modules, and closes all
owned sockets/timers/server handles. No production accounts or credentials
were accessed. No main merge, deployment, archive or upload occurred.
