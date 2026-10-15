# Boss plan attack qualification - 2026-10-08

## Source and repair

Runtime/tests commit: `f66868d61868b35fa76c8aaa106deec91ea8dc31`.
Final test-contract commit: `30397e86b05bc4cca1cc07e524c79142bdad2df9`.
The latter changes three existing perception test files only; runtime/resources
are byte-identical to f66868d, and the natural fingerprint matches both.
Parent: `384b5fb85025feea49fc1347c900109886498e59`.
Branch: `fix/kras-boss-plan-attack-actions`.
Fingerprint, 274 runtime/resource files:
`772dc2205508837982d15c26d1c346e3a9af6856a1d2d2ce76c7e510e3a92c12`.

Two direct BossHunter branches (Colossus attack_plan and Forge feeding_plan)
now publish ATTACK as a tap rather than a held button. Both actual controllers
consume Fighter.is_attacking(), whose start requires a new input edge.
Existing probability/RNG draws, visible delayed observations, geometry guards,
Fighter cooldowns and one-hit-per-Colossus-window rule are unchanged.
The prior generic boss weakpoint tap repair is preserved; continuous tank
fire, Draw and jumping are not altered here.

## Actual input regression

The stationary BossHunter fixture overrides steering only and uses the actual
brain, InputRouter, Fighter timers/buttons and boss contact consumers, across
all four difficulties. Colossus has two explicitly controlled visible openings:
the actual arm-hit consumer must credit exactly one 55 damage hit per opening.
Forge supplies an actual stationary StaticBody3D crate after each swing ends;
its actual feeding consumer must turn every new executed swing into slag.
These are controlled-contact contract tests, not natural physics trials.
Probability zero, hidden target, fresh reaction delay and outside-reach guards
use actual publication. Fixture reaction/chance settings do not change gameplay.

First invocation without an explicit engine log failed before tests with a
user-log access error and native crash (exit 134):
`/tmp/kras-boss-plan-red.log`. The fixture indentation was corrected before
the valid RED run. RED `/tmp/kras-boss-plan-red-corrected.log`: exit 1,
366 passing / 32 failing assertions, 18.5 seconds, no GDScript error.
GREEN `/tmp/kras-boss-plan-green.log`: exit 0, 398 assertions, 30.1 seconds.
Guard expansion initially omitted the helper's brain argument, causing a
parse failure retained at `/tmp/kras-boss-plan-guards.log`; it is not a passing
run. Corrected expanded GREEN `/tmp/kras-boss-plan-guards-fixed.log`: exit 0,
430 assertions, 17.9 seconds, strict positive-summary guard passed.

## Natural and full qualification

Each affected game completed 42 natural matches: 24 baseline, 16 paired
difficulty and two stress variants, with eight verified difficulty pairs.
Both processes exited zero and both start/end fingerprints match the frozen
source. All natural logs passed their runtime guards. No fresh parent
comparison was made: these samples cannot quantify a parent-relative gain.

| Game | Seed offset | Expert score share | Character bias | Slot bias | Tie rate | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| boss_colossus | 1200000 | 0.678788 | 0.116379 | 0.163793 | 0.166667 | none |
| boss_forge | 1200000 | 0.678788 | 0.166667 | 0.041667 | 0 | none |

Colossus baseline: 21 defeated / three survived / zero unknown. Forge baseline:
24 defeated / zero survived. Both difficulty passes: 16 defeated / zero
survived. Both games' two stress variants completed with survived outcomes,
not boss defeats. Colossus ties are retained, not silently discarded.
Both validators report complete execution, `balanceReviewComplete=false` and
`releaseReady=false`. Raw reports: `docs/qa/boss-plan-attack-2026-10-08/`.
Original logs: `/tmp/kras-boss-plan-{game}-1200000.log`.
Wall times: Colossus 287.6 seconds, Forge 120.9 seconds.

First full gate `/tmp/kras-party-check.VdGe7o` stopped with exit 1 after
390480 passing / three failing assertions in 331.7 seconds. The three existing
Forge/Colossus/warning tests inspected held `brain.bits`, which intentionally
does not store tap requests. They now check actual published InputRouter frames,
including both positive requests and negative hidden/delayed-danger guards.
Focused final suites: Forge perception 18 assertions, Colossus approach 112,
boss warning perception 48; all terminal zero with strict guards.
This is not changing thresholds or dropping the failing checks. The original
gate did not reach race/boss/stability stages and is not labeled passed.
Its fresh six captures passed 204 server tests, zero skips, 2041.30575 ms,
log `/tmp/kras-boss-plan-server-tests.log`.

Final source 30397e8 full gate `/tmp/kras-party-check.WeDsOv`: terminal exit
zero. 421 scripts compile; 521 resources, 22 autoloads, 27 routes, eight
characters, zero inventory issues. 390483 assertions passed in 219.2 seconds.
Actual race and all six boss invocations passed. One stability cycle completed
39 matches with zero failures. All stdout runtime guards and the test positive-
summary guard passed. This is not a long soak or physical-device performance
qualification. Intentional negative test diagnostics, simulated memory warning
and native CA-access warnings remain in logs, not an error-free-log claim.

Final server suite used all six fresh captures from this final gate:
204 passed, zero failures/cancellations/skips/todo, 678.609917 ms, terminal exit
zero. Log: `/tmp/kras-boss-plan-server-tests-final.log`.
No runtime/test change after this final source freeze.

## Local network smoke

Four actual scripted Godot clients, Forge seed 309012, exit zero. Host and
guest reconnect passed; all clients agreed on scores `[987,320,160,326]`.
Guest world snapshots: 1851, 1870, 1870. All peer stdout runtime guards passed.
Server loop maximum 136 ms. Cumulative client frame gaps 674/762/662/652 ms
include scene loading/reconnect, not steady-state FPS. Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-EOKqKi`.
Summary log: `/tmp/kras-boss-plan-network.log`. Raw peers remain local because
they may contain resume credentials. Not public Internet, four physical users,
all-game online, tournament or native-device performance qualification.

## Release gates

Live production health returned on 2026-10-08:
`ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`.
No production change, backup/export, migration or online enablement performed.
Previous Chrome verification found ASC 1.1.10 (107), not this source.
Current all-game balance/product audit, unresolved seat warnings, physical
iPhone/iPad measurements, safe production rollout and exact-source local
Xcode 27 Distribution archive still gate Apple upload and review submission.
No main merge, phone installation, archive, signing, upload, processing or
Apple submission performed by this repair. No Xcode Cloud or P12 import.

Read-only `npm audit --omit=dev --json` completed with exit zero and zero known
dependency vulnerabilities on 2026-10-08; raw output remains at
`/tmp/kras-boss-plan-dependency-audit.json`. This does not certify application
security, production configuration or native authentication end to end.
