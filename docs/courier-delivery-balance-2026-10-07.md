# Delivery AI Natural Balance Evidence

Tested checkout: e717a594b6d6d234f14bdd00cc1ce68f5573f9c0.
Runtime change: 333c237159e2c3ec4583fc433b910c2145811f69 (PR 169).
Godot: 4.7.1-stable (official).
Simulation fingerprint before/after every run and in the current content audit:
fdfa206ff2e6882166652b1bafbc09fe3b7602871046eecaa16199cf0d6ed2dc.

Each report contains 24 naturally completed baseline matches, 16 mirrored
Easy/Expert comparisons with the same seed and character, and two successful
mutator/chaos matches: 126 complete matches across the three reports. Both
processes for offset 1500000 and the independent Star Rush process exited 0.
All three stdout logs passed tools/check_godot_log.sh. No clipped-round flag
was used and no gameplay files changed during these runs. README changes
are outside the simulation fingerprint and do not modify runtime behavior.

| Game / Offset | Mean Match Seconds | Expert Score Share | Slot Bias | Character Bias | Ties | Slot Wins |
| --- | --- | --- | --- | --- | --- | --- |
| Star Rush / 1500000 | 95.0194 | 0.691358 | 0.190000 | 0.075000 | 1/24 | 4, 7, 3, 11 |
| Crate Relay / 1500000 | 90.0194 | 0.678788 | 0.134615 | 0.105769 | 2/24 | 10, 6, 4, 6 |
| Star Rush / 1800000 | 95.0194 | 0.695652 | 0.046296 | 0.134259 | 3/24 | 5, 8, 6, 8 |

All report flags are empty. Keep the first Star Rush result: its fourth-slot
advantage warranted the independent run. The second sample is less uneven,
not proof that spawn advantage is impossible. Joint winners can make slot wins
sum above 24. Expert score share is not a character win-rate certification.
Durations include the match flow; they are not isolated active-round clocks.

Raw reports are retained alongside this document:
- courier-star-natural-1500000.json
- courier-relay-natural-1500000.json
- courier-star-natural-1800000.json

Logs: /tmp/kras-courier-star-natural.stdout,
/tmp/kras-courier-relay-natural.stdout,
/tmp/kras-courier-star-independent.stdout.
Save/progress directories have corresponding /tmp/kras-courier-*-save names.

## Content Gate

Current party_content_audit accepted the report fingerprint/engine/coverage
for these two games with no balance-evidence issues. All 39 definitions passed
structural validation; statuses are READY=0, NEEDS_POLISH=2, NEEDS_BALANCE=37,
REWORK=0, BROKEN=0. The 37 missing current-source reports are not 37 proven bugs.
The audit never grants READY without real-device and game-specific acceptance.
Audit log: /tmp/kras-courier-content-audit.log;
generated report: build/party/content-audit.json.

## Documentation Audit

README now describes the implemented protocol-2 WebSocket rooms, host/server
responsibilities, endpoint and service gates, without claiming production online
acceptance. It describes bundled Noto fonts and CC0 environments instead of
claiming every asset was authored here or that no licensed fonts are shipped.
All five font SHA-256 values match assets/fonts/README.md; both export presets
include the original OFL files. The ten local README links exist.
Replay documentation distinguishes matching results in the short Zone Hold test
from the chaotic Ring Rumble test, which does not require identical scores.
This is a documentation correction, not a fresh copyright or full replay audit.

No main merge, Railway deployment, version/build change, signed Archive, upload
or Apple review submission occurred. Campaign 37577604329 remains a separate
live handle on c5fa1f9; do not count it as qualification of this later source.
Final source promotion, all-game QA, four-human vehicle readability, actual
iPhone/iPad sustained performance and auth, production backup/restore and online
rollout, local Xcode 27 Distribution Archive/signature/source verification,
processed upload and correct review-state confirmation remain required.
