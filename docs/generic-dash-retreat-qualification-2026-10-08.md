# Generic dash retreat contract qualification

Parent: `0e0b525b6b76810e86bd73a28594e065003d7256`.
Frozen runtime/tests: `2d576f40332526abf9ab87289d5af8a8829c2741`.
Branch: `fix/kras-generic-dash-retreat-contract`.

## Repair

Generic scheduled follow-through retreat only when held `bits` changed around
`maybe_dash`. Shared DASH uses `_tap_bits` now, so its accepted dash no longer
triggered retreat. Compare the complete pending action mask (`bits | _tap_bits`)
before and after that existing helper. This does not drain or publish input.
No helper signature, probability, dash guards, physical cooldown, character,
perception or balance threshold changed. The previously unreachable existing
retreat-duration RNG draw is restored when a dash request is accepted; natural
trajectories/RNG sequence may consequently differ from the broken parent.

## Actual decision regression

Four tiers, accepted / disabled / empty meter / zero chance / hidden rival.
Real Generic decision, actual perception, InputRouter publication and Fighter
button handling; no replacement for the decision or dash helper. Stationary
fixtures force offence/accepted probability and remove acquisition delay/noise
only for isolation. Accepted requests must execute a Fighter dash, schedule
0.35-0.75 seconds of retreat, move away on the next decision and release DASH.
Rejected requests cannot start retreat or the Fighter cooldown.

RED: 286 passed, 12 failures across four tiers, 17.5 seconds;
`/tmp/kras-generic-dash-retreat-red.log`.
GREEN: 298 passed, 29.9 seconds, strict guard zero;
`/tmp/kras-generic-dash-retreat-green.log`.
This is decision/input contract evidence, not a natural balance result.

## Natural samples

Ring Rumble and Duo Clash: 84 matches total, each 24 baseline + 16 paired
difficulty + two stress matches, eight verified difficulty pairs each. Both
terminal exits zero, strict guards passed, both stress variants passed.
Start/end fingerprint matches the frozen runtime (274 files):
`0004544429fd22d441e15fb5d4a150aec2ba6b5d43087eb0ced8da82c7392eb8`.
Raw reports: `docs/qa/generic-dash-retreat-2026-10-08/`.

| Game | Offset | Expert share | Character bias | Seat bias | Ties | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| ring_rumble | 1200000 | 0.656250 | 0.166667 | 0.083333 | 0.000000 | none |
| duo_clash | 1200000 | 0.573964 | 0.116379 | 0.129310 | 0.208333 | none |

Duo's five baseline ties are retained. No fresh parent comparison or all-game
balance acceptance is claimed. Both validators retain
`balanceReviewComplete=false` and `releaseReady=false`.

## Local network

Four scripted human Godot processes, Duo Clash seed 309010, terminal exit zero,
all four strict guards zero, scores agree: `[94,81,90,82]`. Host and one guest
resumed. Guest world snapshots: 864/845/864. Server max event-loop delay 38 ms;
cumulative client frame gaps 593/583/597/601 ms include loading/reconnect, not
steady frame-time or physical-device thermal/energy measurements. This single
local match is not public Internet or complete tournament acceptance.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-JQWw0z`.
Raw peer logs remain local because they may contain resume credentials.

## Historical all-game campaign

Run 37670303689 was freshly verified completed/success on
`d5524b9c95f7122b598932ff1f84a07d19c26fb5`. Downloaded campaign summary reports
39 games / 1638 matches, verified paired comparisons, no missing games, but
retains Scrap Karts `expert bots no better than easy`. Colossus baseline has
22 defeats / two survivals; all four bosses survived both stress variants.
`balanceReviewComplete=false` and `releaseReady=false` remain in that summary.
Retained file: `historical-campaign-37670303689-summary.json` under the QA folder.
This old source lacks subsequent shared/direct dash, crate attack and this
retreat repair. Its successful execution cannot qualify any of those changes.

## Full regression and server gate

Evidence: `/tmp/kras-party-check.1qAivQ`, terminal exit zero. All 421 scripts
compile; 521 resources, 22 autoloads, 27 routes, eight characters, zero
inventory issues. 390351 assertions passed in 315.0 seconds. Actual race and
six boss invocations passed; one stability cycle: 39 matches, zero failures.
All stages passed their strict guards. No runtime/test changes during
qualification. Intentional negative harness/save/router/replay diagnostics,
simulated memory warning and native CA-access warnings remain in logs; this
is not an error-free log, long soak or physical-device performance claim.

Server tests used all six fresh world captures from this gate's `saves-tests`:
204 passed, zero failures/cancellations/skips/todo, 984.494666 ms, terminal
exit zero. Log: `/tmp/kras-generic-retreat-server-tests.log`.
Localhost test permission was used; protected production data untouched.

## Remaining release scope

Current-source all-game balance and product audit, direct Keeper/Ball action
contracts, Lab seat warning diagnosis, physical-device QA, production rollout
and a fresh exact-source local Xcode 27 Distribution archive remain required.
Earlier Lab samples on 2cca6cc had seat wins [1,7,12,4] and [4,12,5,3]: both
flagged, but the leading seat differs. Do not infer one fixed unfair slot or
change thresholds without stronger diagnosis.
No main merge, protected production operation, phone installation, native
archive, Apple upload or review submission is performed here.
