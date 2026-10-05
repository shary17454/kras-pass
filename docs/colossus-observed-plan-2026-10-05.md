# Colossus Observed Attack Planning

Runtime source: `dc7acb6ae50890b73d534ee884ceaf4187e2b3cb`.
Branch: `fix/kras-colossus-observed-attack-plan`, based on the preceding
`fix/kras-boss-weak-point-perception` patch, not merged into main.

## Correction

The Colossus hunter previously requested an attack plan that read the live fist
position directly. A controlled actual-scene regression recorded an attack
against the hidden fist. The red test exited one with 45 passing and five
failing assertions: `/tmp/kras-colossus-observation-before.log`.

The exposed fist now supplies its actual rendered node to the shared weak-point
observation layer. The hunter passes delayed visible positions to `attack_plan`.
An explicit empty observation set cannot fall back to the current hidden fist.
The legacy single-argument planner remains available for other consumers.
Existing crater-safe approach, vertical reach, dash clearance, damage, exposure
window and difficulty profiles were not changed.

The warning-priority fixture now observes the fist before introducing a fresh
warning decision, separating fist acquisition from warning reaction delay.
It still requires an attack before the warning is perceived and escape after
the full delay; no assertion or warning threshold was weakened.

Focused tests passed: weak-point perception 51 assertions, warning perception
48. Logs: `/tmp/kras-colossus-observation-fixed.log` and
`/tmp/kras-colossus-warning-after.log`. These are constructed scenes, not
physical rendered human playtests. Forge feeding-plan perception still requires
separate work, as do other specialized agent/object queries.

## Committed-Source Checks

Full runner: 359818 assertions passed in 150.3 seconds. Compilation: 368
scripts. Inventory: 408 resources, 21 autoloads, 27 routes, eight characters,
zero issues. Four AI racers completed the actual three-lap race. Colossus seeds
345, 9614 and 172 defeated the boss; Forge, Dreadnought and Sovereign seed
9614 also passed their natural boss probes.
The complete wrapper exited zero after all 39 single-cycle stability matches
finished with zero failures; log guards passed for all steps.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.idChj9/`.
These samples do not establish statistical character balance or all-game
Internet, touch/gamepad, orientation, battery, thermal or iOS performance QA.

## Production Deployment Supersedes Pending Observations

The previously observed automatic deployment
`574f7937-8d0b-4875-829f-a356f2b6781d` completed SUCCESS without a restart or
duplicate deploy. Production repository `shary17454/kras-pass`, branch main,
source `049e66019a4a8a8c41e9bdbc2262505c1741234b`; running instance
`95acd072-1c97-480d-a4a0-75d74a8e243e`.
This deployed main does not contain the two subsequent AI development branches.

The final effective manifest uses DOCKERFILE, `/Dockerfile`, `/health` and a
100-second healthcheck timeout. The initial RAILPACK/no-Dockerfile observation
was not the final manifest. Direct build logs show Dockerfile loading, Node 24,
successful npm installation, zero reported package vulnerabilities and
`[1/1] Healthcheck succeeded!`. Requested deployment logs show volume mount and
`node index.js` startup with no error in that bounded sample.

Fresh API probes returned health 200 (`ok=true`, `authentication_ready=true`,
`multiplayer_enabled=false`), unauthenticated account 401 `sign_in_again`, and
Apple challenge 200 with correctly typed id/nonce/expiry. Sensitive challenge
values were not printed. The client account endpoint in `src/net/apple_account.gd`
matches this production domain.

Required account/Apple variables were checked without printing raw values:
all present; client/team/owner match intended configuration, key ID format
valid, private key parses as EC, database path `/data/accounts.sqlite`.
Read-only SSH to the exact new instance returned quick_check=ok, zero
foreign-key errors and user_version=0. No schema migration or production
variable change was performed. This is not a new restore rehearsal or live
Apple-user/device authentication acceptance.

No new Apple Archive, Distribution verification, upload, processing or review
submission occurred. All remaining product, physical-device, balance,
Internet/reconnect, persistence and exact-source release gates remain required.
