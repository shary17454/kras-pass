# Derby Contact Closing Qualification

## Source And Correction

Branch: `fix/kras-derby-contact-closing`, based on the separately reviewed
crater performance branch `71a519ba47b5d72b5eeeadbf3508bea0b608761e`.
Runtime/test commit: `bed40e2823751361c8f32ae47bf65b72fe71b8eb`.
No automatic main merge or production deployment of this branch.

Scrap Karts previously used the magnitude of relative velocity as collision
closing speed. Nearby riders moving apart, sliding sideways or moving only
vertically could therefore take damage, generate impact feedback and consume
contact cooldown despite not approaching along their separation axis.

The fix projects relative velocity onto the flat normalized contact direction
and clamps separating motion to zero. Existing contact range, speed threshold,
damage scale, flank reward, backwash, cooldown, scoring, health, AI parameters
and character stats are unchanged. Reversing into a contact still counts as
approaching; chassis facing remains relevant only to the existing flank reward.

## Red And Focused Green

The unchanged runtime failed 16 new assertions: four cases each verified
feedback generation, both riders' health and the pair cooldown. Cases were
separating, tangential, vertical, and subthreshold normal velocity combined
with large lateral velocity. The red run ended with 75 passed and 16 failed.
Log: `/tmp/kras-derby-closing-red.log`.

The corrected focused suite passed 97 assertions. Additional positive cases
rotate an actual head-on collision across two axes, verify unchanged normal
damage/backwash and ensure large vertical velocity cannot amplify damage.
Existing replica validation, feedback deduplication, host health restoration,
round reset and cooldown checks remain enabled.
Log: `/tmp/kras-derby-closing-final-focused.log`.

## Natural Matched And Independent Campaigns

Baseline source: main `3c6db5816857df68c7900fdd86c9ca445a2a2904`.
The intervening crater optimization did not change Scrap Karts, its driver
brain or Fighter (`git diff` verified those paths), and it does not use the
crater floor. Baseline main compiled all 384 scripts before comparison.

Each report completed 24 baseline matches, 16 mirrored difficulty matches
across all eight characters and two stress matches. Authored round windows
were retained. `tools/balance-report.mjs` checked seeded samples, pairing,
counts and stress results using explicit local checkout identities; these
are local qualified reports, not GitHub artifact provenance receipts.
Runtime guards passed and both tracked sources were unchanged after runs.

| Source | Seed Offset | Mean Seconds | Expert Share | Slot Bias | Character Bias |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before, current main | 600000 | 16.4000 | 0.4691 | 0.0833 | 0.0833 |
| Corrected contact | 600000 | 28.8750 | 0.5000 | 0.1250 | 0.1250 |
| Corrected, independent | 900000 | 28.8576 | 0.5063 | 0.1250 | 0.0417 |

All 126 matches completed, including both stress modes in each report. The
flag `expert bots no better than easy` remains in both corrected reports;
the slight change in place share does NOT establish Expert advantage or
READY status. The earlier full39 historical mean of 16.663 seconds is not
this fresh matched baseline's 16.400 seconds. Longer duration after removing
phantom hits is not itself evidence of enjoyable pacing or good balance.

Reports:
`/tmp/kras-derby-closing-baseline-ready-report/report.json`,
`/tmp/kras-derby-closing-after-report/report.json`,
`/tmp/kras-derby-closing-independent-report/report.json`.

The first fresh-checkout baseline invocation failed parsing because it had no
Godot imported class cache and was stopped; it is excluded. Fresh import was
started, then intentionally stopped to reuse already generated Godot 4.7.1
asset cache from the tested checkout. An import scan completed and the clean
baseline compilation passed before the successful natural run. Sandbox denial
when saving editor settings and the existing macOS CA diagnostic are not
claimed as editor/TLS-system health. No player save was used or erased.

## Actual Local Network Check

`network-smoke.js --game=scrap_karts --humans=2 --seed=438683058` passed with
actual Godot peers plus bots, host and guest movement/reconnect, matching
scores `[24,8,28,4]`, 1388 guest world snapshots and existing ram/wreck/health
replica checks retained. Server-loop maximum was 55 ms, not an Internet latency
qualification. Runtime guard passed.
Log: `/tmp/kras-derby-closing-two-peer.log`.

## Full Regression And Release Gates

The unchanged runtime completed `GODOT_BIN=/opt/homebrew/bin/godot sh
tools/check_party.sh` with exit 0 and a passing runtime log guard. All 385
scripts compile. Inventory: 425 resources, 21 autoloads, 27 routes, eight
characters and zero issues. Full suite: 360761 assertions passed in 371.8
seconds. The real three-lap race and six boss regressions passed. Stability
completed 39 default-arena matches with zero failures; ordinary windows are
shortened, so this is not natural balance or all-map/device qualification.
Five-second settled Godot static memory was 441319032 bytes and 183 resources;
retained memory remains unresolved and is not phone RSS/GPU evidence.
`git diff --exit-code bed40e2823751361c8f32ae47bf65b72fe71b8eb -- src tests`
verified the frozen code after all checks.
Log: `/tmp/kras-derby-closing-full.log`.
Artifacts:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.64RfIo`.

Current main CI `37390678273` has successful core, ring and goal jobs at
inspection, with remaining network matrix pending and balance skipped. This
does not prove branch CI or complete Internet qualification. Production online
play remains disabled. No Apple archive, signing, upload or review submission
occurred. Balance/pacing, memory and physical device orientation, FPS,
battery/thermal QA remain unresolved release gates.
