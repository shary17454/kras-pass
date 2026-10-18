# Recorded Three-Way Tank Final

Parent: `dd8841165c43b6cf3fd01dbf40ef86df24e935c6`.
CI run 37859085528, tank job 113590273569 failed final armor-hit evidence.
The recorded final seed is 1962702799, tank_foundry, contenders [0,2,3],
standings [10,7,10,10]. The new fixture restores preceding results only.
The final uses four real Godot peers, local WebSocket transport, ordinary
movement, pickups and projectiles. No final scores or armor are injected.

The first local replay passed with scores [475,100,460,460], but hit the
watchdog. Inspection exposed a fixture defect: it replaced the production
20-second final clock with 30 seconds, exceeding its 25-second safety limit.
The regression failed two assertions before the duration repair. Ordinary
tank fixtures retain 30 seconds; contender finals now retain 20 seconds.

After repair, the same final passed with scores [200,100,425,300], champion
slot 2, identical standings and results at all four peers, no watchdog,
and successful host plus spectator reconnect. Server loop maximum 28 ms
is not an iPhone frame-rate measurement.

Focused network suite: 403 assertions pass, 1.7 seconds. Checkpoint accounting:
four Node tests pass. All 439 scripts compile. Strict guards pass focused
tests, compilation and the final host log. Evidence including guest logs
is retained in `../qualification-tank-three-final-2026-10-09/`.

CI now includes the recorded three-way fixture alongside the earlier
two-human final. The earlier campaign was not cancelled or restarted.
This fixes qualification fidelity, not a proven runtime no-hit defect.
One local pass does not resolve the original CI failure or demonstrate all
seeds, scheduling conditions, device performance or full release acceptance.
No gameplay injury requirement was removed. No production deployment,
main merge, archive, upload or review submission occurred.
