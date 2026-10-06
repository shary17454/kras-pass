# Tag Hunt Contact Selection Qualification

## Source And Scope

Baseline: `main` at `6ff1f360e7cbab79e35e441cfa6d867d6165631b`.
Runtime fix: `494d475f0f09342964e703df432c55eee6cca9d1`, on
`fix/kras-tag-contact-selection`. The source remained unchanged throughout
the tests and natural simulations, verified with `git diff --exit-code`.

The previous contact loop awarded the hunter role to the first eligible
runner in player-slot order. When multiple runners were touching the hunter,
a farther low-slot runner could be selected instead of the closest runner.
The new loop selects the closest contact inside the existing 1.7 m radius.
Exactly equal distances use the match's seeded RNG, avoiding permanent
low-slot preference while retaining reproducibility. One tag per tick,
the 1.3 s grace period, scoring, speed multipliers and AI settings are unchanged.

## Regression And Integration Evidence

- Before the runtime fix, the added closest-contact fixture failed four
  assertions: slots 2 and 3 lost to the farther slot 1.
- After the fix, the complete tag networking suite passed 234 assertions.
  Coverage includes nearest contacts in each runner slot, a single award,
  grace protection, equal-contact eligibility, reproducibility across repeated
  seeds, and selection of both eligible slots across 64 fixed seeds.
- Compilation passed for all 386 scripts.
- The resource audit reported 427 resources, 21 autoloads, 27 routes,
  eight characters and zero issues.
- The full test runner passed 360,969 assertions in 415.0 s.
- `tools/check_godot_log.sh` passed for compile, inventory, full tests,
  both natural campaigns and both network smoke runs. The macOS system-CA
  lookup warning is separately allowed by that existing guard; it is not
  an application GDScript failure.

Logs: `/tmp/kras-tag-contact-red-engine.log`,
`/tmp/kras-tag-contact-green-engine.log`,
`/tmp/kras-tag-contact-compile.log`,
`/tmp/kras-tag-contact-inventory.log`, `/tmp/kras-tag-contact-full.log`.

## Natural Comparison: Balance Still Incomplete

Two isolated campaigns used the same seed offset 600000, 24 natural
90-second baseline rounds, 16 matched-seed/character difficulty rounds,
and two short mutator/chaos smoke rounds each: 84 matches in total.
All baseline seeds and mirrored difficulty configurations matched.
`summarizeBalance` validated both complete 42-match local campaigns against
the eight character IDs from `data/characters.json`, with pairing required.
The supplied provenance identifies local frozen checkouts, not GitHub CI runs.

| Metric | Baseline | Fixed |
| --- | --- | --- |
| Average natural duration | 90.0167 s | 90.0167 s |
| Expert placement-point share | 0.4539877301 | 0.4601226994 |
| Slot bias | 0.125 | 0.125 |
| Character bias | 0.125 | 0.125 |
| Expert tags in difficulty samples | 53 | 53 |
| Easy tags in difficulty samples | 232 | 232 |
| Mutator / chaos smoke | PASS / PASS | PASS / PASS |

Both reports retain `expert bots no better than easy`. This fix corrects
contact arbitration; it does not explain or solve the difficulty imbalance.
The unchanged tag totals suggest pursuing the interaction of escape strategy
and tag rewards next, rather than claiming this collision fix balanced AI.
That is an investigation direction, not a proven cause.

Reports: `/tmp/kras-tag-main-natural-report/report.json`,
`/tmp/kras-tag-after-natural-report/report.json`.
Logs: `/tmp/kras-tag-main-natural-engine.log`,
`/tmp/kras-tag-after-natural.log`.

## Real Local Network Processes

`network-smoke.js --game=tag_hunt --seed=438683058` passed separately
with two and four Godot peers and a real local WebSocket service.
All peers moved and agreed on scores. Host and one guest disconnected
and resumed successfully; the other two peers in the four-peer run stayed
connected and were not independently disconnected.

- Two peers plus two bots: scores `[38,35,13,10]`, 1088 guest world snapshots.
- Four automated human-input peers: scores `[37,15,25,17]`,
  1087-1107 guest world snapshots.
- Server event-loop maximums were 387 ms and 293 ms respectively under
  concurrent headless test load. These are not phone rendering-FPS results
  or evidence of acceptable Internet latency.

Logs: `/tmp/kras-tag-contact-two-peer.log`,
`/tmp/kras-tag-contact-four-peer.log`.

## Production And Release Boundary

The production deployment was read independently during this qualification:
Railway `e3511b26-8a15-4952-9ddb-4110094679b6` was `SUCCESS`, from
`shary17454/kras-pass`, branch `main`, commit
`6ff1f360e7cbab79e35e441cfa6d867d6165631b`.
`/health` returned `ok=true`, `authentication_ready=true`, and
`multiplayer_enabled=false`. The fetched startup log contained six info
entries and no errors; this small sample does not establish long-term stability.
This new tag fix is on a separate branch and is not in that deployment.

No production variable was changed, and no Apple archive, upload or review
submission was performed. Balance, physical iPhone/iPad performance and
orientation QA, complete online qualification and final signed-source release
gates remain open. Tag Hunt must not be marked READY from this evidence.
