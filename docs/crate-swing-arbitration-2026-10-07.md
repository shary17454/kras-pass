# Simultaneous crate swing arbitration

Runtime source: `510e1d4fa288bc9a7f9458a4f4efe1bb4357dec5`.
Expanded typed test source: `af0a3aab9fdb178e92f8d549d537faba7779363d`.
The simulation roots are byte-identical between these commits; the second
commit only gives the fixture's RNG state variable an explicit integer type.

## Defect and repair

Crate Smash checked attackers by seat and immediately removed a contested
crate. Thus seat 0 won even when another attacker was much closer. Lab Crates
inherits this code. Regression fixtures on both actual controllers establish
this independently of the historical campaign's sampled seat-bias warning.

Now each crate selects the nearest eligible attacker within the unchanged
reach, excludes dead/non-attacking players and players already served this
tick, and resolves exact distance ties using the gameplay seed. Unique nearest
selections consume no random draw. One crate per player per tick remains the
limit. Invalid crate entries are safely removed. Lab's weapons, penalties and
effects still use its existing `_break_crate` implementation.
No character stats, AI difficulty, rewards or balance thresholds were changed.

## Tests

Original runtime plus regression: 833 passed, 12 failed, demonstrating closer
seats 1-3 losing and exact ties always going to seat 0 in both games.
`/tmp/kras-crate-arbitration-red.stdout`.
Initial repair: 845 passed, verbose strict log guard passed.
`/tmp/kras-crate-arbitration-green.stdout`.
Expanded fixture initially failed to load because an RNG state inferred from
the untyped scene variable required an explicit type. This failed run is kept
in `/tmp/kras-crate-arbitration-expanded.stdout`, not treated as green.
Corrected expanded fixture: 987 passed, verbose strict log guard passed.
`/tmp/kras-crate-arbitration-expanded2.stdout`.
Network snapshot suite: 160 passed, strict guard passed.
`/tmp/kras-crate-network.stdout`.
Round reset suite: 92 passed, strict guard passed.
`/tmp/kras-crate-rounds.stdout`.
Compilation: all 420 scripts passed, strict guard passed.
`/tmp/kras-crate-compile.stdout`.

## Natural comparison

Same offset 1200000; each sample has 24 baseline, 16 verified matched
difficulty, and 2 mutator smoke matches. Logs pass strict runtime checks.
Parent: `019ca2be8c84732f6bae4bcdbbd26dd47f09f0c8`, fingerprint
`f2a3888bd8b301928cc943aacad789f0d4412a7c9c7c2f69633e683bb449f2b1`.
Candidate: 510e1d4, fingerprint
`0bb8ed8339b32f917284b874885bfdbaa8e0d90d82a7425b20c118fa73606c13`.
All 272 simulation files and report start/end identities independently verified.

| Lab Crates | Expert score share | Character bias | Seat bias | Flags |
| --- | ---: | ---: | ---: | --- |
| Parent | 0.691358025 | 0.0833333 | 0.0833333 | None |
| Candidate | 0.691358025 | 0.125 | 0.0416667 | None |

The parent already lacked the historical campaign warning on these seeds.
Therefore this repair is not claimed to explain or remove that older warning.
The deterministic contested-swing defect is proved by its direct regression.
Sampled lower seat bias is not proof of universal balance improvement;
character bias increased within the unchanged acceptance threshold.
Raw reports: `docs/qa/crate-swing-2026-10-07/`.

Crate Smash natural qualification completed on af0a3aa: 42 matches at offset
1200000, paired seeds/source independently verified and strict runtime guard
passed. Expert score share 0.682926829, character bias 0.1666667, seat bias
0.0416667, zero ties and no report flags. Raw report:
`docs/qa/crate-swing-2026-10-07/crate-smash-after.json`.

## Full source gate and four-client integration

Frozen tested checkout: `6dcc15525894364635cb6149fa0448c1cd726744`.
The 272-file simulation fingerprint remains the candidate fingerprint above.
`GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`
completed with exit 0. Evidence: `/tmp/kras-crate-full-gate.stdout` and
`/tmp/kras-party-check.3LJw1F`.

- 420 scripts compiled; inventory: 519 resources, 22 autoloads, 27 routes,
  8 characters, zero issues.
- 390091 assertions passed (310.8 seconds), followed by the actual three-lap
  race, six boss regressions and 39 stability matches with zero failures.
- All stage log guards passed. This is one stability cycle, not a long soak
  or physical-device battery/thermal qualification.
- Fresh server tests used all six world fixtures captured by this run:
  204 passed, zero failed/cancelled/skipped/todo, 843.469708 ms.
  Evidence: `/tmp/kras-crate-server-tests.log`.
- Dependency audit reported zero vulnerabilities in
  `/tmp/kras-crate-audit.json`; this is not a complete security audit.

`node network-smoke.js --game=lab_crates --humans=4 --seed=309001`
completed with exit 0 using four real Godot processes, scripted inputs and a
local WebSocket service. The authored 90-second rounds were not shortened.
All clients agreed on `[71,29,62,24]`; host and one guest reconnected.
Guest world snapshot counts were 4108, 4108 and 4089. All four client logs
passed the separate strict runtime log guard. This is not four human players
or a production Internet test.

Evidence: `/tmp/kras-crate-lab-four-network.stdout` and
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-KWT50U`.
Server maximum event-loop delay was 222 ms. Cumulative maximum frame gaps by
process suffix 0/1/2/3 were 820/827/815/824 ms. The measurement includes loading
and transitions; it does not establish the stall's cause or steady-play FPS.
These results must not be advertised as smooth 60 FPS or phone performance.

An earlier parent full gate failed its exit ObjectDB leak guard. This source
did not reproduce that leak, but its cause remains unidentified; the previous
failure is not erased or represented as fixed.

## Release gates still open

Native device/performance checks, production validation and App Review
submission are not completed. The existing local Xcode 27.0 (27A266a) and
Distribution identity were verified, but identity availability is not archive,
signature verification or upload evidence. Older archives exclude this repair.
Railway health returned ok/authentication_ready true and multiplayer_enabled
false; that does not qualify production online play or latest-source sync.
App Store Connect returned to login with authResult=FAILED during the fresh
browser check, so current build inventory and submission status are unverified.
No main merge or production/Apple state-changing action was performed.
