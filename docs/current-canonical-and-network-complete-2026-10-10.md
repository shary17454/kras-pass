# Current canonical simulation and completed older-source network campaign

## Current-source local campaign

Clean checkout at start: `904f76dca2cfc861b95de9f23f491edd2e426bf1`, branch
`feature/kras-online-random-rotation`. Gameplay includes the Lab spawn repair
in `73a2ea97fa361a74ab03dc8d9b56e1f2be530e25` and armed-race pickup repair.
Godot `4.7.1-stable (official)`, isolated imported runtime
`/tmp/kras-tank-pursuit-check`, four AI players, each game's default arena.

Run label `local-canonical-2026-10-10-be795`, seed offset `56000000`.
Started 2026-10-10 06:02:48 UTC; completed 07:14:38 UTC, process exit 0.
39 games x (24 baseline + 16 matched/mirrored difficulty + 2 smoke) =
1638 completed match instances. Baseline/difficulty use natural declared
durations and actual race laps; mutator/chaos smoke retains its shorter window.
Roster policy is the existing `adjacent_rotation`, not the previous experimental
balanced-roster campaign. All smoke cases pass.

Selected simulation source fingerprint, checked before/after each game and at
completion, remains:
`be7952428ad72f69703dfa8d918427c7d8e42e1466d5007445c0a527c16316dd`.
This fingerprints selected src/scenes/data/tools file types and project.godot,
NOT all assets, tests, native binaries, signing or an App Store archive.
Local execution metadata explicitly identifies a local run, not GitHub CI.

The unchanged official balance aggregator accepted all 39 reports, verified
paired seed/character comparisons, counts, source and boss outcome evidence.
All 78 stdout/engine logs pass the strict runtime guard. The policy regression
suite preceding the campaign passes 7643 assertions and its completed-tests guard.
No production code, tests, thresholds or runtime data changed during the campaign.

## Remaining balance warnings

| Game | Warning | Expert point share |
|---|---|---|
| storm_heart | Expert no better than Easy | 0.519231 |
| blast_ball | Expert no better than Easy | 0.512500 |
| scrap_karts | Expert no better than Easy | 0.503067 |
| sweeper_storm | Character advantage; Expert no better than Easy | 0.487500 |
| base_siege | Expert no better than Easy | 0.518293 |

Each has only 24 baseline and 16 matched difficulty samples. Sweeper character
bias is 0.25: Fanoos won 9/24 baseline games. These are review signals, not proof
of a specific code defect. Do not lower the threshold or tune only to this seed
cohort. Larger independent samples and fair-perception review remain necessary.
Earlier independent-cohort warnings are not erased by a clean sample here.

Boss baseline defeated/survived: Forge 24/0, Colossus 18/6, Dreadnought 24/0,
Sovereign 22/2. Unknown outcomes: zero. Completion alone does not qualify human
difficulty, enjoyment or device performance.

The existing content auditor consumed each original per-game report via
`--recheck`, exit 0, strict runtime guard PASS. All 39 have no structural or
balance-evidence identity/count issues. Status: NEEDS_BALANCE=5,
NEEDS_POLISH=34, READY=0, BROKEN=0, REWORK=0. It does not promote device QA.

## Completed network evidence, different source

[GitHub run 38022898755](https://github.com/shary17454/kras-pass/actions/runs/38022898755)
completed successfully on `c0a5b6c6d3b9cb0875c47aa9c87c5ada1ce39b9c`.
40 jobs succeeded (core + 39 network games); the separate balance job was SKIPPED.
Do not label that job as executed or use this source for the later pickup/Lab fix.
The updated human-matrix CI integration is also newer and not covered by this run.

All 40 artifact identities verify checkout/intended commit, run ID and clean
tracked state. Read-only downloaded-log audit: 177 groups, 542 peer stdout logs,
strict runtime guards, unique peer IDs, identical scores/round histories/arena
histories/tournament data, and restored host ID 1 in every group. Groups include
83 two-human and 94 four-human configurations. Client ID 2 reports restoration
in 107 cases; not every scenario disconnects that client.

Non-tournament cases contain one match and empty tournament data. Actual
tournaments report complete=true. The first local log-auditor attempt wrongly
required tournament completion for single-match tests and failed; only that
reader assumption was corrected, not runtime tests or acceptance thresholds.
21 moved=false terminal records have a final spectator=true round; do not
misclassify these non-participating terminal seats as stuck active players.
Bounded shared champions after repeated ties remain an existing policy, not a
claim that every tournament always produces one champion.

This is test-host evidence, not Railway production, physical clients, a new
server-authoritative simulation or current-source online qualification.

## Evidence, Git and release gates

Tracked summaries: `current-canonical-summary-2026-10-10.json` and
`current-canonical-content-audit-2026-10-10.json`.
Original reports/logs, local runner, network log auditor and GitHub run metadata:
`../qualification-canonical-and-network-2026-10-10/`.
Temporary campaign: `/tmp/kras-be795-canonical-2026-10-10/`.

Fresh git fetch verified origin main at
`062a40992b92958573e28e19d8c8c1840560797a` and remote feature at
`5b07018a6358368a6cddc0f6ec68f2cd617df55d`. Six local commits preceded this
documentation-only phase; the new phase is saved locally as Update project.
The rejected main promotion was not bypassed through another push/deploy.

Public Railway health returned ok=true, authentication_ready=true,
multiplayer_enabled=false. No production database/secret access or migration.
Approved durable production backup/restore, current-source online/device QA,
balance review, fresh local-Xcode archive and release acceptance remain open.
Refreshing App Store Connect redirected to login; a login request is pending.
No P12 import/password request, new certificate, main merge/push, Railway
deployment, native archive rebuild, upload, withdrawal or review submission.
Stage 0 remains QA_PENDING/MERGE_PENDING; no READY/DONE promotion.
