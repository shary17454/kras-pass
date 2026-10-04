# Network Single-Tick Input Qualification

## Source And Scope

- Runtime fix baseline: `57e0d6d9c8977dcf5ae183f0cbc3cf2c3acd91da`.
- Branch: `test/kras-network-single-tick-taps`.
- This change modifies the peer test driver, not game rules or scoring.
- Quick Draw submits one physics-tick attack per observed public signal sequence.
- No hidden countdown, forced score, forced outcome, or altered response window is used.
- Independent processes use the actual local WebSocket service and match lifecycle.
- The existing smoke fixture uses two internal rounds with a 15-second duration override.
  This is not full authored-duration balance qualification.

## Corrected Evidence Lifetime

The runtime fix clears remote controls on transport loss, preventing stuck buttons.
The peer test previously checked `Net._inputs` after intentionally dropping the
host result transport. That cache is now correctly empty at this point.
The test now records slots whose actual packets were observed during each match,
resets that evidence at match start, and requires all remote slots at results.
It still requires gameplay observations, matching results, guest reconnect, and
host result-delivery recovery. It does not preserve stale controls to pass a test.

## Executed Checks

- First single-tick smoke failed with `missing remote inputs` after a real result.
  Log: `/tmp/kras-single-tick-network-smoke.log`.
- Corrected smoke exited zero for both two humans plus two bots and four humans.
  Log: `/tmp/kras-single-tick-network-smoke-observed.log`.
  Evidence directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-nGAHbw`.
- Two-human scores matched: `[12, 2, 4, 6]`.
- Four-human scores matched: `[12, 0, 2, 2]`.
- Both scenarios recovered the guest connection and host result transport.
- Focused network suite: 144 assertions passed; runtime log guard passed.
  Log: `/tmp/kras-single-tick-focused-tests.log`.
- `git diff --check` passed.

## Remote CI And Remaining Gates

Main run `37164624299` for the baseline was still active at observation.
Completed Ring Rumble and Goal Guard jobs failed with the same obsolete
post-disconnect cache assertion. Their downloaded logs are:
`/tmp/kras-57e0d6d-ring-job.log` and `/tmp/kras-57e0d6d-goal-job.log`.
This does not qualify the remaining jobs or prove every failure has that cause.
The amended peer fixture still needs the full remote game matrix.

Local scheduling was slow: observed server event-loop maximum was 1539 ms.
These runs establish functional input/result behavior, not latency acceptance,
60 FPS, device temperature, battery use, internet connectivity, or physical QA.
Production Online remains disabled pending qualification. No new iOS archive,
App Store upload, or review submission was performed in this qualification.
