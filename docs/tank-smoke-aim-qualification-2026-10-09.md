# Tank smoke pilot aiming qualification

## Scope and observed issue

Base commit: a95982fa3d5861a7216f2a4af2edc43284b9133e.
The failed Linux networking job in run 37890891082, source 19f21be, reported
shots and ammunition pickups but no armor damage in the three-contender final,
seed 1962702799, arena tank_foundry. That failed run remains failed.

The scripted human test pilot accepted a facing dot product greater than 0.9
(about 26 degrees). At ten meters this can miss a chassis by several meters.
It also gated ATTACK with a 180ms wall-clock window every 700ms. These are
observed weaknesses in the test driver, not established causes of every Linux
failure or evidence of a shipping projectile bug.

The pilot now requires a clear horizontal firing corridor, positive forward
distance beyond the muzzle, nearby target, compatible ground height and at
most 0.4m lateral error. While aligned, it holds ATTACK; the existing game
cooldown controls ammunition and firing rate. Other vehicle smoke pilots are
unchanged. Rival ground height is retained separately from horizontal steering.

No shipping source, projectile collision, damage, armor, scoring, tournament
rules or evidence requirements were changed. In particular, the final
observer still requires shots, armor damage and ammunition pickup.

## Local checks

- Network suite: 420 assertions passed; strict log validation passed.
- All 442 Godot scripts compiled; strict log validation passed.
- Full regression: 405309 assertions passed in 204.9s; strict log validation
  passed. The expected save-write failure fixture is not a runtime regression.
- Ordinary actual WebSocket + Godot matches: two humans plus Bots and four
  humans both passed with scripted controls. Host and one guest reconnected.
  Result scores were respectively [500,515,500,600] and [880,600,300,300].
- The recorded three-contender final completed two tiebreak rounds at epochs
  4 and 5 with four actual peers. Scores [450,100,500,500], then
  [100,200,420,300]; champion slot 2, unchanged cups [2,1,2,2] and points
  [10,7,10,10]. Host and guest reconnected. Exit 0.

Initial test authoring attempts had GDScript parse errors: reflection methods
were invoked on a preloaded class instead of a Script value. Those logs are
preserved and are not claimed as valid gameplay RED tests. Loading a typed
Script value corrected the fixture; the final suites have no script errors.

## Outstanding gates

The fresh Linux tank-only workflow must qualify this candidate before claiming
the remote failure is resolved. A local pass is not Linux acceptance. Tank-only
diagnostics are not a current-source all-39-game release gate.
Character balance, remaining full product scope, physical iPhone/iPad QA,
production backup/restore authorization, Railway deployment and exact-source
local Xcode archive/upload/App Review remain separate and incomplete.

## Evidence

Raw logs: `../qualification-tank-aim-2026-10-09/`.
Three-contender individual peer logs:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-QhnWEk`.
