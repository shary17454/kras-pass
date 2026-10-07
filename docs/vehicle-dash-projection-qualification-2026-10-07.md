# Actual Vehicle Dash Direction: Qualification and Open Release Bugs

Runtime commit: `f2a50fde79e70732ec436b11a9ecf95df01b99d0`.
Qualified fixture-repair commit: `d103bf0e59fe7c328860061947da88e76500eded`.
Branch: `fix/kras-vehicle-dash-projection`, stacked on driver engagement memory.

## Reproduced Safety Error

The actor already dashes along vehicle facing, but AI's lethal-edge projection
interpreted steering/throttle as world X/Z. It could accept an outward dash,
reject an inward dash, and skip the safety check for stationary input even
though the real actor then uses facing. The test reproduced all three failures:
2 passed / 3 failed, exit 1 (`/tmp/kras-vehicle-dash-red.stdout`).

`Fighter.dash_direction()` now centralizes the existing actor direction semantics.
Both the actual impulse and AI projection use it. DRIVE uses facing; WALK/FLOAT
use the input or the original near-zero fallback. Actor impulse strength,
cooldowns, profiles and the nonlethal-track bypass are unchanged.

Expanded tests compare the projection against actual `_do_dash` impulses across
all three locomotion modes and four input vectors: 29 assertions pass and the
strict log guard passes (`/tmp/kras-vehicle-dash-expanded.stdout`).

## Full Regression, Including a Retained Failed Gate

Initial full gate on f2a50fd: `/tmp/kras-party-check.HlfJ2v`, exit 1. Its test
counter reported 388681 passes, but the strict log guard caught two script errors
in a pre-existing dodger jump timing fixture whose `Arena.def` was null. This
is a FAILED full gate, not a successful qualification.

d103bf0 supplies the timing fixture a valid `ArenaDef`, without suppressing
runtime errors. Focused timing suite: 65 pass, strict guard 0.

Fresh complete command:
`GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`.
Evidence `/tmp/kras-party-check.rsPWIe`, completed exit 0, every stage's strict
log guard passed:

- 417 scripts compile; inventory 516 resources, 22 autoloads, 27 routes,
  8 characters, zero issues.
- 388681 assertions pass in 306.1 seconds.
- Actual three-lap Party Race and six explicit defeated-boss checks pass.
- 39 stability matches, zero failures. Settled texture/material/mesh/PCM caches
  are zero; process memory 140255964 bytes. This is one cycle, not a long soak
  or native phone FPS/heat/energy proof.

Fresh six real engine world captures from `rsPWIe/saves-tests` pass the server
suite: 204 pass, zero fail/skip, 3442.9 ms. Log
`/tmp/kras-vehicle-dash-server-tests.log`. This is loopback integration, not
production Railway or Internet/reconnect qualification.

Fresh `npm audit` reports zero known dependency advisories at inspection.
`/tmp/kras-dash-projection-npm-audit.json`. This does not certify overall security.
Known macOS CA diagnostic, intentional failed-save/route fixtures and simulated
memory warning remain visible; no log guard was relaxed.

## Natural Balance Remains Unaccepted

Two samples on f2a50fd each completed 24 baseline rounds, 16 mirrored difficulty
rounds and two short smoke checks. Existing validator confirms counts, seeds and
all eight character pairs; strict runtime guards pass. Both retain the warning
`expert bots no better than easy`, with Expert shares 0.47826087 (offset 1200000)
and 0.5125 (1500000), unchanged from the engagement-memory parent. The safety
repair does NOT claim to resolve this balance weakness.

Raw reports: `dash-projection-scrap-natural-1200000.json` and
`dash-projection-scrap-natural-1500000.json`. Both start/end fingerprints:
`9e3f834d96a8e940717a43914a8159d36580a0ad9dccf9ef747c34daef7e7f5e`.
The test-only fixture repair does not alter that simulation source fingerprint.
`releaseReady=false` remains true of the validator's judgment.

## Higher-priority Winner Contract Counterexample

The Arabic/English Scrap Karts rule says last kart running wins. Actual
`compute_scores()` and `MatchResult.make()` were exercised in a real four-player
match context with a coherent sequence: P1 eliminates P2/P3, then P0 eliminates
P1. Alive slots `[0]`, elimination order `[2,3,1]`, KOs P0=1/P1=2.

Observed scores `[12,14,2,4]` and winners `[1]`: the eliminated runner-up wins
over the actual last survivor. Evidence
`/tmp/kras-scrap-winner-scene-diagnostic.stdout`, exit 0/strict guard 0.
The diagnostic uses an isolated save directory and does not finish/store a
user match. An initial standalone `--script` attempt had an autoload compilation
failure and was terminated (exit 130); it is NOT the counterexample evidence.

The local-scene diagnostic is not a random full-match replay, but it directly
proves the scoring/declared-win-condition mismatch. Fixing this contract takes
priority over trying to tune difficulty statistics against the wrong winner.
Also investigate driver target choice: live `ctx.scores` do not identify a
leader in Scrap Karts, while `priority_rival()` may reroll tied co-leaders.
That observation is a diagnostic lead, not a proven complete AI repair.

## Release Boundaries

No main merge, database action, Railway rollout, phone replacement, new signed
archive, upload or Apple submission occurred. Both inherited vehicle candidates
remain unaccepted. Fix the winner contract and retained balance warnings, then
obtain current all-game/native/device/production evidence and a new exact-source
local Xcode 27 Distribution archive. Simulator source investigation is recorded
separately; it is not native renderer equivalence or device qualification.
