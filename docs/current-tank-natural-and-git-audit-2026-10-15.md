# Current tank natural campaigns and release-state audit

Status: CAMPAIGNS_COMPLETED / BALANCE_NOT_ACCEPTED.
Stage 0 remains QA_PENDING / MERGE_PENDING. No READY/DONE promotion.

## Source And Method

Source commit: 5fb0e7ad0516def620a3633458711f1fcbb73fe0.
Branch: feature/kras-online-random-rotation. Checkout clean before the runs.
Godot 4.7.1, headless fixed FPS 60, tests/balance_pair_sim.tscn, natural durations.
Each campaign ran 112 baseline matches, 56 completed matched difficulty
comparisons and two mutator/chaos smoke matches: 170 instances each, 680 total.

All four runs recorded the same gameplay fingerprint at start and end:
2f90389f023b6b1c6632a41917a78cdb90ef85013d6e2d61e5c073fcaffd02c4.
A final external runtime fingerprint matched. The committed archive was
previously matched to this runtime, including edited test files, in
../qualification-tank-edge-2026-10-15/source-attestation.md.
No source, test, rule, threshold or runtime edits overlapped the campaigns.
The earlier 425358-assertion full-suite result covers this unchanged gameplay.

## Results

| Arena / seed offset | Wall time | Seat wins P1/P2/P3/P4 | Expert point share | Average simulated duration | Flags |
| --- | --- | --- | --- | --- | --- |
| Oasis / 96000000 | 155.3 s | 41/13/37/21 | 0.4267857143 | 16.380655 s | spawn slot advantage; expert bots no better than easy |
| Frost / 96000000 | 96.4 s | 37/17/25/33 | 0.4660714286 | 10.621577 s | expert bots no better than easy |
| Foundry / 96000000 | 299.0 s | 31/27/19/35 | 0.5357142857 | 15.114732 s | none in this sample |
| Oasis / 97000000 | 180.5 s | 44/13/42/13 | 0.4339285714 | 13.933185 s | spawn slot advantage; expert bots no better than easy |

All completed with exit 0 and passed the strict runtime log guard. No baseline
ties or all-zero-score rounds were reported. Both smoke matches passed in each
campaign. These are successful executions, not successful balance acceptance.

External assertions checked complete attempts/difficulty rows, all-eight
character exposure, 14 appearances per seat per character, all 28 pairs meeting
24 times, and valid MD5 envelope checksums/schema 2 in isolated profile, backup
and settings files. No secret settings values were printed or copied.

The three 96000000 map cohorts use identical baseline seeds/rosters and are
matched map comparisons, not three independent cohorts. The 97000000 cohort
has no seed overlap with the Oasis reference across baseline, difficulty and
smoke channels. Its repeated warning supports further investigation; Foundry's
clean sample does not erase warnings on other maps or earlier sources.
Wall times are not phone FPS, battery, heat or memory-leak measurements.

## Next Causal Diagnostic

Static inspection suggests an authored-road access asymmetry in Oasis:
default cardinal spawn points correspond to road nodes 22, 15, 24 and 4;
the central node is 23. North/south have direct central edges, while the east/
west approaches must reach inner-loop nodes 20/9 first. The same five crate
node indices are also used across different road layouts.

This is a hypothesis, not proof that roads or crates alone cause the measured
win gap. Next measure actual shortest route lengths, terrain grade and cover
clearance from all four starts. Only then try a map-local correction and repeat
matched/held-out comparisons. Do not shuffle slot labels, relax thresholds or
change character stats merely to remove a report warning.

## Fresh Git And Public Production Check

Origin is https://github.com/shary17454/kras-pass.git.
The initial git fetch origin completed successfully, but the configured fetch
refspec covers only feature/kras-online-random-rotation. It did NOT refresh main.
An explicit fetch of refs/heads/main to refs/remotes/origin/main then completed
successfully and advanced the remote-tracking main from 062a409 to:
66efebee5e8c68c2071a13b2a7a7d6c6c06b521e (Update project).

At the audited source commit 5fb0e7a, local feature was 27 commits ahead of its
fresh remote counterpart. Versus freshly fetched main, the graph had one
remote-only commit and 461 local-only commits. These counts precede this
documentation commit and are not permanent branch properties.

The remote-only changes are three documentation/evidence files: the stage
ledger, docs/duel-independent-2026-10-12.json, and
docs/release-completion-2026-10-12.md. They were read as historical evidence on
an older source/Linux environment, not current acceptance or authorization.
No merge, rebase, history rewrite, checkout switch or push was performed.

The public production /health endpoint at
https://kras-pass-production.up.railway.app/health returned HTTP 200, ok=true,
authentication_ready=true and multiplayer_enabled=false. This flag is not a
real login test and health does not identify the deployed commit. Production
online readiness, repository linkage, environment secrets, database/migrations,
backup/restore approval and native production connectivity are not verified by
this read-only check. No production settings or services were mutated.

No Xcode archive, signing, Apple upload, processing or review submission occurred.

## Preserved Evidence

../qualification-5fb0e7a-natural-2026-10-15/ holds four complete engine logs and
their JSON/HTML reports. Original isolated saves remain under /tmp, not copied.
Report SHA256 values:

- Oasis matched: 1360edad217e3c86c0fad27a315acf680bdc2f053ed091eb857a2e4295eb501c.
- Frost matched: fa23c041e27726ae0398972c0eaa87925221158bba6c21e4c96d16094d78279e.
- Foundry matched: 22bbebaa765bddf353f8cf73a6c6e6d46ff30ed4f80e4b2a21a4b77544b4fd77.
- Oasis held-out: a77e3aaecfde062a0d5891dacb6ad5c36a4e2b05e0f411b113ee123b17b3a257.
