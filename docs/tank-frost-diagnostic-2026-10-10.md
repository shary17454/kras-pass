# Tank Frost Network Diagnostic

## Open Failure

GitHub run 37993034226 at `5fe84cd25a1ee6032a6c81d80af4e5ac45eb0f89`
failed the four-human tournament's second round, tank_frost, at seed
1421670522. Shots and inventory were observed, but all armor stayed at 100.
The first round used seed 968660540 and did record damage.

The previous logs did not include the pilot's facing, alignment or clear-path
decision. The network test now records those fields, its movement command,
target/distance and narrow can-fire decision alongside existing ATV evidence.
This changes diagnostics only: no runtime, pilot behavior, acceptance rule,
damage threshold, timer, inventory or winner logic changed.

## Local Check

At parent `d1921dedc162eb1e923c8b0b04ecc26f04db8def`, with the changed
network test copied into the existing temporary qualification checkout:

`node network-smoke.js --game=tank_arena --tournament --humans=4 --seed=1421670522`

completed with exit 0 and four matching peer reports. The tournament completed
foundry, frost and oasis rounds, with final scores `[500,200,100,416]`, points
`[9,8,8,8]` and champion slot 0. Host and another peer reconnected successfully.
All four engine logs passed strict error/leak checks.

This run used the supplied seed for every round. It is **not** a replay of the
original sequence, timing or machine. It did not reproduce the original missing
damage, and therefore does not prove that failure fixed. Keep the original
failed run and diagnose any recurrence using the additional fields.

- Network unit tests: 420 assertions, exit 0, strict completed-test log pass.
- Compile check: 448 scripts, exit 0, strict runtime log pass.
- Changed test file byte-compared to the tested temporary copy.
- `git diff --check` passed.

Evidence: `../qualification-tank-frost-diagnostic-2026-10-10/`.
Original failed artifacts: `/tmp/kras-tank-failure-5fe84cd-37993034226/`.

The core CI run 37995167985 at parent d1921de was still running at this
diagnostic checkpoint. A new tank-only campaign is required at the diagnostic
commit; do not cancel the distinct core run to launch it. Current full-network,
remaining product/balance, physical-device and production/release gates remain
open. No main promotion, deployment, Apple upload or submission occurred.
