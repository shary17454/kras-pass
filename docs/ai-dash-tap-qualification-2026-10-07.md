# AI dash one-shot action qualification

Parent: `61c1aec77aef12c5679f8f9906c6a60b9108d7de`.
Frozen runtime/test source: `420996a9094466825f771099ea9dff9cb6c3a92b`.
Branch: `fix/kras-ai-dash-tap-actions`.

## Repair

`Fighter._handle_buttons` consumes DASH through `just_pressed`, with the actual
dash cooldown and charge guards. `AIBrain.maybe_dash` previously published a
held button between decisions. Consecutive accepted dash decisions therefore
remained one continuous press and could not trigger a new dash after cooldown.
Change only the final request from `press(Btn.DASH)` to `tap(Btn.DASH)`.
No probability, RNG draw count, perception, edge projection, cooldown, impulse,
character stat, AI profile or acceptance threshold is changed.

The facing/backoff and ram-alignment experiments remain rejected. Their
gameplay changes are not included. This repair restores the one-shot input
contract; it does not claim to solve all balance issues.

## Focused proof

The new fixture exercises actual AIBrain publication, InputRouter frames,
Fighter timer advancement and button handling over 181 physics ticks for all
four tiers. Movement is held stationary and decision acceptance forced only in
the fixture; this isolates repeated input edges and actual cooldown, not
natural perception, movement or character balance.

Original RED: 162 passed, eight failed (repeated edges and post-cooldown boosts
failed at each tier), `/tmp/kras-ai-dash-red.log`.
Candidate plus empty walking charge guards: 178 passed in 20.2 seconds,
`/tmp/kras-ai-dash-green.log`. Actual cooldown permits at least three and no
more than four boosts over the fixture window; empty meter publishes no dash
and starts no cooldown. Vehicle projection guards: 29 passed in 1.3 seconds,
`/tmp/kras-ai-dash-vehicle.log`. Boss weak-point perception: 55 passed in
3.4 seconds, `/tmp/kras-ai-dash-boss-perception.log`.
All three strict log guards passed.

Old assertions inspecting the held-only `brain.bits` were updated to inspect
actual published actions. Positive inward/respawn and negative outward/crater
cases remain; assertions were not removed to accommodate the tap change.

## Natural balance

Three new candidate samples and one fresh parent comparison: 168 matches.
Each report contains 24 baseline, 16 paired difficulty and two stress matches.
All eight difficulty pairs per report and stable start/end fingerprints were
verified independently. Every run exited zero and passed its strict log guard.
Candidate: 274 files,
`5c0d3feb196919ed40cac0fc6fb903ce87f48cef66d5d3a4dd80aa0934d158a2`.
Separate detached parent checkout at 968aab7: 274 files,
`e4de1862c596dd6d865362f1ece93c10f1ade749356ef22d544ffc91bbdfbb73`;
its gameplay is identical to 61c1aec. Asset/data differences are zero.

| Game | Source | Offset | Expert share | Character bias | Seat bias | Warning |
| --- | --- | --- | --- | --- | --- | --- |
| Scrap | prior parent runtime | 1200000 | 0.493750 | 0.083333 | 0.083333 | Expert no better than Easy |
| Scrap | candidate | 1200000 | 0.506250 | 0.083333 | 0.166667 | Expert no better than Easy |
| Scrap | prior parent 968aab7 | 1500000 | 0.596273 | 0.041667 | 0.041667 | none |
| Scrap | candidate | 1500000 | 0.602484 | 0.041667 | 0.041667 | none |
| Fawda | fresh parent 968aab7 | 1200000 | 0.606250 | 0.125000 | 0.208333 | none |
| Fawda | candidate | 1200000 | 0.625000 | 0.125000 | 0.083333 | none |

All baseline tie rates are zero. The Scrap first-cohort warning and increased
seat disparity remain visible; do not label Scrap balanced. Both Fawda samples
are unflagged: this is not proof of clearing an old warning from a different
source. Small samples do not establish statistical superiority. This verified
input repair still needs all39 qualification and balance review.
Selected-game validation `complete=true` is execution coverage only; all
reports retain `balanceReviewComplete=false` and `releaseReady=false`.
Raw reports: `docs/qa/ai-dash-tap-2026-10-07/`.

## Local four-client network check

`/tmp/kras-ai-dash-scrap-network.log`, seed 309007, four scripted human clients,
one Scrap match, local WebSocket server. Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-uEUWjy`.
Exit zero; all four agree on scores `[6,18,24,14]`; host and one guest resumed.
Guest world snapshots: 1332, 1332, 1313. Each peer stdout passed the strict
guard. Maximum server event-loop delay: 29 ms. Cumulative client maximum frame
gaps: 605, 620, 597, 609 ms, including startup/loading/reconnect, not steady
60 FPS proof. Full peer logs remain local because they can contain resume
credentials. This is not a public Internet, physical-input, whole-tournament,
adversarial authority, thermal or battery qualification.

## Full regression and server gate

Full wrapper `/tmp/kras-ai-dash-full-gate.log`, evidence
`/tmp/kras-party-check.wXapGR`, completed exit zero. Compile and inventory
completed without GDScript/resource issues; 421 scripts, 521 resources,
22 autoloads, 27 routes, eight characters. Tests: 390231 assertions passed in
376.2 seconds. Actual race regression and all six boss invocations passed.
Stability: one cycle, 39 matches, zero failures, with explicit cache release
after a simulated memory warning. Every stage passed its strict log guard.
Intentional negative-save/router/replay-budget/memory-warning diagnostics and
native certificate-store access warnings remain in logs. This is not an
error-free-log claim, a soak test or device performance evidence.

Fresh server tests used all six world captures under this gate's isolated
`saves-tests`: 204 passed, zero failed/cancelled/skipped/todo, 1159.21 ms;
`/tmp/kras-ai-dash-server-tests.log`. Localhost permissions were granted only
for test execution. Production and protected data were untouched.

## Remaining release scope

No main merge, protected production data operation, Railway deployment,
phone installation, native archive, Apple upload or review submission occurred.
All39 campaign 37670303689 remains on d5524b9 and cannot qualify this repair.
Do not mark the full goal complete. Final qualification, balance, physical
device and production gates precede a new exact-source local Xcode 27 archive.
