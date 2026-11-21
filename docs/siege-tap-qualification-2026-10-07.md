# Siege crystal input qualification

Runtime/test commit: `8086b914b031a8d2f3678feba23e10176ce5e755`.
Branch: `fix/kras-siege-tap-actions`; parent `dbb38388191a9d8e94ba00d27f3a56fe51e9133f`
has the same runtime as `f3f489f66bf36bcc8681b4ddf93151e179238b5a`.
No main merge, production deployment or Apple upload/submission.

## Defect and direct proof

SiegeBrain's crystal-specific attack still held ATTACK across decisions, even
after the shared rival helper used taps. Fighter starts its attack and emits
`attacked(slot)` only on a new input edge. Repeated crystal decisions could
therefore stop damaging a reachable crystal after the first swing.
This branch converts only that crystal-specific request to the existing tap.
No stats, profile probabilities, reaction/visibility policy, RNG draw count,
damage, reach, cooldown, rules or balance acceptance thresholds changed.

The stationary fixture exercises the real SiegeBrain decision, InputRouter,
Fighter cooldown/button handling, attacked signal and BaseSiege crystal damage.
It isolates movement and forces zero reaction/noise/mistakes only in the fixture.
Before: 82 passed, 8 failed (repeat edges and repeat crystal damage in all tiers),
`/tmp/kras-siege-tap-red.log`. After: 90 passed, strict guard passed,
`/tmp/kras-siege-tap-green.log`. Crystal damage per swing, cooldown bounds and
own-crystal protection are asserted. Rendered base perception suite: 85 passed,
strict guard passed, `/tmp/kras-siege-tap-perception.log`.

## Natural matches and retained limits

Each candidate sample completed 24 baseline, 16 verified paired difficulty and
2 mutator smoke matches: 126 natural matches total. All logs passed strict checks.
All 272 simulation files and report start/end hashes independently matched
`4424c3bd757b75f76985228bcb0a8c15282d831ff804b34614f43e44eda08e94`.

| Seed offset | Expert score share | Character bias | Seat bias | Tie rate | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| 1200000 | 0.554878049 | 0.195 | 0.11 | 0.0416667 | None |
| 1500000 | 0.588957055 | 0.0416667 | 0.0833333 | 0 | None |
| 1800000 | 0.618181818 | 0.0833333 | 0.1666667 | 0 | None |

The before report at 1200000 is retained in
`docs/qa/melee-tap-2026-10-07/base-siege-after.json`: Expert 0.537037037,
character bias 0.1666667, seat bias 0.25, spawn-advantage warning.
Its 272-file fingerprint `d91c97e31bf6de281cd84d76a807277e79a4aa40a7fe3dc7285710174f35a680`
was rechecked against the exact f3f489f Git tree, not current files.
Candidate reports: `docs/qa/siege-tap-2026-10-07/`.
The direct defect is proved; clearing sampled warnings is not universal balance
proof. Character bias increased on the first cohort and one baseline draw was
retained. Other games' historical warnings are not qualified by these samples.

## Exact-source full gate

`GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh` completed
with exit 0: `/tmp/kras-party-check.H9FJwS`.
420 scripts compile; 519 resources/22 autoloads/27 routes/8 characters/zero issues.
390143 assertions passed in 276.3 s. The actual three-lap race, six boss checks,
39 stability matches (zero failures) and all strict stage log guards passed.
The deliberate memory-warning fixture drained caches; it is not a phone warning.
This is one stability cycle, not a long soak or proof of absent memory leaks.
The earlier parent exit ObjectDB leak remains unexplained, not claimed fixed.
Fresh server tests used all six world captures from this exact gate:
204 passed, zero failures/skips/cancelled/todo, 1286.005375 ms;
`/tmp/kras-siege-tap-server-tests.log`.

## Four-client local network fixture

Four actual Godot processes and a localhost WebSocket server completed Base
Siege on source 8086b91, seed 309003. Scripted inputs, 45-second fixture rounds,
not four physical humans or authored-duration Internet qualification.
All agreed on `[9,24,43,20]`; host and guest reconnected; guest world snapshot
counts 1155/1174/1174. All four stdout logs passed the separate strict guard.
Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-do5WG0`.
Maximum server loop delay: 116 ms. Cumulative maximum client frame gaps by
process 0/1/2/3: 726/716/718/721 ms. Timing includes loading/transitions;
stall cause and steady-play FPS are not established. No smoothness/phone claim.

## Release gates

Fresh Railway health: ok/authentication_ready true, multiplayer_enabled false.
No production rollout, protected account/database export or migration performed.
Fresh Chrome UI still showed ASC login with authResult=FAILED. Current build
inventory is not verified; no new native archive/upload/review submission.
Physical iPhone/iPad gameplay, energy/thermal/FPS, all-game current balance,
production online acceptance and full product acceptance remain open.
Only local Xcode 27 is permitted for the eventual native archive, not Xcode Cloud.
