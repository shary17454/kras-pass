# Siege inactive attacker regression

The host now rejects stale attack signals from eliminated slots or inactive
fighter bodies. Dash collisions also require an active fighter body. Guest
presentation-only ownership and ordinary damage/cooldown rules are unchanged.

The network presentation suite isolates three negative cases by restoring the
fixture baseline between them. Each checks both crystal health and attacker
score, preventing one unexpected cooldown from masking the next case.

Before the runtime fix, all six new assertions failed: eliminated and inactive
attacks reduced health from 78 to 65; an inactive dash reduced it to 69. Each
incorrectly awarded a point. After the fix, all 98 assertions passed.

Evidence on the development host:

- `/tmp/kras-siege-isolated-before.log`: 92 passed, six failed, exit 1.
- `/tmp/kras-siege-isolated-after.log`: 98 passed, zero failed, exit 0.

This is a focused runtime and replication test, not full online qualification,
physical-device performance validation, or an App Store submission. The final
round evidence contract and Kart Sprint session watchdog remain separate work.
