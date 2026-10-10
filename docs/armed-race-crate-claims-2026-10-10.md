# Armed Race Crate Claims And Expanded Balance

## Before The Pickup Change

Clean tracked source at start: c0a5b6c6d3b9cb0875c47aa9c87c5ada1ce39b9c.
Runtime fingerprint before/after the simulation and in the checkout:
81d4dd3e0a19fe021cb38bff175bcf98c0a57d0cdd8940c264137de09032ba02.
Godot 4.7.1 official, natural dune_circuit rounds, balanced seeded partitions
with seat rotation, seed offset 32000000. No source edits during simulation.

All 96 baseline + 48 matched-seed/character difficulty + 2 stress matches
completed in 854.0 wall-clock seconds. Average baseline round: 127.593 seconds.
Expert share 0.70; slot bias 0.0104167; character bias 0.0833333; flags=[];
mutator/chaos passed. The runtime log guard passed.

Wins: barq 15, fanoos 14, ghaim 18, mowja 20, nabta 8, ramla 12, sakhra 5,
turs 4. This is not proof that all characters or arenas are equally balanced.
The older 15279bf/24-race adjacent-rotation warning at character bias 0.25
remains retained; differing rosters/source/sample sizes cannot establish a
causal fix or simply erase its review history. No character stats were changed.

## Independent Pickup Defect

The authoritative crate loop granted a pickup to the first eligible seat in
range, even when a later seat was closer. Equal-distance pickups always went
to the lowest seat. This was confirmed independently of the balance warning.

The loop now collects the final nearest-distance contenders, grants a unique
nearest claim without consuming an extra RNG draw, and uses the match's seeded
RNG only for a true nearest tie. Inventory, cooldown, crate count, authoritative
event generation and sound are awarded exactly once. Existing eligibility
checks for finished/recovering/dead racers and occupied inventory remain.
Guests still render host snapshots; no client pickup simulation was added.

## Tests

The initial added test had a local type-inference parse error; that failed log
is retained. After correcting the test's explicit int type, the unchanged game
produced 513 passing and 6 failing assertions: three later-seat nearest cases
and three seats never receiving tied pickups. After the game fix: 519 passed.

Coverage includes all four nearest-seat choices, exactly one item/event,
unchanged unique-claim RNG consumption, two repetitions of each of 64 seeds,
tie eligibility for each seat in that fixed seed set, occupied inventory and
finished-racer exclusion, plus the existing network presentation/reconnect
and weapon-event regression. It is not a statistical fairness certification.

Full regression: 408170 assertions, 223.5 seconds, exit 0 and strict test guard
pass. Compile: 450 scripts, exit 0 and runtime guard pass. Server: 276 passed,
zero failures/skips, against six actual world captures from this full run.
git diff --check passed.

Current runtime fingerprint:
c6997498a03697a4c59d66bb1cf99ef2016098bc982dcaf88ace346df6e1cf81.
The earlier natural sample above precedes the pickup fix and cannot be
relabeled current-fingerprint balance evidence.

## External Gates

Network campaign 38022898755 remains nonterminal on c0a5b6c. Ring Rumble and
Goal Guard jobs completed successfully; later games remain queued/running.
No cancellation/restart was issued. It does not qualify the new pickup source.

Fresh local device inspection found the physical iPhone 16 Pro Max connected,
passcodeRequired=false and unlockedSinceBoot=true. No install, app data read,
deletion or physical gameplay/energy acceptance was performed here.

No main merge, Railway production mutation, new native archive, Apple upload
or review submission. The previous signed archive is older-source evidence;
freeze the final release source and rebuild before uploading. All-game current
qualification, physical-device/controller/performance QA, production backup/
restore authorization/migrations/connectivity, and unfinished product scope
remain open. No READY/DONE status was granted.

Evidence retained outside Git: ../qualification-race-crate-claims-2026-10-10/.
