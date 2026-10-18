# Sweeper Exposure Diagnostics

Parent: `88db4dd0ffe776949aebcc78d99c9a4069bf4826`.
Branch: `feature/kras-online-random-rotation`.

The development contact probe now records simulated alive seconds and jump
input requests per slot. Exposure ends on first elimination or round results.
Duplicate elimination cannot extend it. Requests are not accepted jumps:
stun, airborne state or game rules may reject a request. These metrics apply
to the runner's single-round matches, not arbitrary multi-round tournaments.
No character, physics, AI, scoring or release configuration was changed.

## Verification

- Seventeen focused assertions pass, including a fake physics clock,
  duplicate elimination, survivor exposure and reset. Strict runtime guard:
  `/tmp/kras-contact-exposure-unit-fixed.log`.
- All 429 scripts compile; strict compile guard passes:
  `/tmp/kras-contact-exposure-compile.log`.
- Observed run: 24 baseline, 16 matched difficulty and two smoke matches,
  seed offset 3500000. All 42 JSONL rows are completed, have zero invalid
  contacts, finite exposure bounded by round duration and nonnegative
  integer jump-request counts.
- Same-source, same-seed uninstrumented control has identical full report
  content after removing only `generated`. Both source fingerprints remain
  `051fc839dabff190a0a0873a7caa81b2f419384ec9f48f4347473a3e9a4252f0`.
  This proves noninterference for this sample only.
- Initial exposure unit attempt is rejected: a negative engine-start tick
  caused a null assertion and runtime error despite a positive test summary.
  The fake clock fixes the test rather than weakening the log guard.

Evidence: `docs/qa/sweeper-exposure-2026-10-08` contains both reports and the
observed trace. Runtime logs remain under `/tmp/kras-sweeper-exposure-*`.

## Interpretation

Each character has 12 baseline appearances. Environmental hits per alive
second: Nabta 0.546, Sakhra 0.749, Fanoos 0.698, Ramla 0.712, Barq 0.700,
Mowja 0.754, Ghaim 0.605, Turs 0.723. These rates remove part of the survival
exposure confound, but do not prove a resistance, jump or collision defect.
Ghaim's input requests cannot be interpreted as successful jumps.

The earlier 96-match character advantage warning remains unresolved. No
balance thresholds were weakened and no speculative character nerf applied.
This diagnostic does not qualify all 39 games, device performance, the
production backend, or an iOS release. No archive, upload or review submission
was performed by this follow-up.
