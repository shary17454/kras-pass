# Current Minigame Evidence Snapshot

Source: `e5bd09499448b92b4cdc26b5d890526e156c3cc8`.
Simulation fingerprint:
`af354bc49e94b6c247269af1ca05bf5d4e0c263566d23fefae5b82fb49920813`.
These statuses describe current qualification, not 38 newly discovered gameplay
bugs. Old measured campaigns remain useful historical evidence but cannot
automatically certify changed simulation sources. No game is marked READY.

Quick Draw seed offset1200000 completed 24 natural baseline matches,16 paired
difficulty matches and two mutator/chaos matches without balance flags. Its
start/end fingerprints match the current audit and engine4.7.1. This small
sample is not statistical proof of perfect fairness or physical device QA.

| Game | Status | Remaining Evidence |
| --- | --- | --- |
| tank_arena | NEEDS_BALANCE | Missing or stale current-source qualification |
| ring_rumble | NEEDS_BALANCE | Missing or stale current-source qualification |
| crumble_court | NEEDS_BALANCE | Missing or stale current-source qualification |
| bumper_bowl | NEEDS_BALANCE | Missing or stale current-source qualification |
| fawda | NEEDS_BALANCE | Missing or stale current-source qualification |
| goal_guard | NEEDS_BALANCE | Missing or stale current-source qualification |
| magnet_court | NEEDS_BALANCE | Missing or stale current-source qualification |
| storm_heart | NEEDS_BALANCE | Missing or stale current-source qualification |
| sky_court | NEEDS_BALANCE | Missing or stale current-source qualification |
| blast_ball | NEEDS_BALANCE | Missing or stale current-source qualification |
| scrap_karts | NEEDS_BALANCE | Missing or stale current-source qualification |
| turret_duel | NEEDS_BALANCE | Missing or stale current-source qualification |
| gem_grab | NEEDS_BALANCE | Missing or stale current-source qualification |
| star_rush | NEEDS_BALANCE | Missing or stale current-source qualification |
| paint_grid | NEEDS_BALANCE | Missing or stale current-source qualification |
| mnatiq | NEEDS_BALANCE | Missing or stale current-source qualification |
| mukharrib | NEEDS_BALANCE | Missing or stale current-source qualification |
| zone_hold | NEEDS_BALANCE | Missing or stale current-source qualification |
| crate_smash | NEEDS_BALANCE | Missing or stale current-source qualification |
| lab_crates | NEEDS_BALANCE | Missing or stale current-source qualification |
| crate_relay | NEEDS_BALANCE | Missing or stale current-source qualification |
| hurdle_dash | NEEDS_BALANCE | Missing or stale current-source qualification |
| kart_sprint | NEEDS_BALANCE | Missing or stale current-source qualification |
| color_stand | NEEDS_BALANCE | Missing or stale current-source qualification |
| symbol_echo | NEEDS_BALANCE | Missing or stale current-source qualification |
| quick_draw | NEEDS_POLISH | Current minimum sample; device/playability sign-off missing |
| rising_tide | NEEDS_BALANCE | Missing or stale current-source qualification |
| sweeper_storm | NEEDS_BALANCE | Missing or stale current-source qualification |
| duel_pit | NEEDS_BALANCE | Missing or stale current-source qualification |
| boss_forge | NEEDS_BALANCE | Missing or stale current-source qualification |
| boss_colossus | NEEDS_BALANCE | Missing or stale current-source qualification |
| boss_dreadnought | NEEDS_BALANCE | Missing or stale current-source qualification |
| boss_sovereign | NEEDS_BALANCE | Missing or stale current-source qualification |
| sabaq_sawarikh | NEEDS_BALANCE | Missing or stale current-source qualification |
| relic_hold | NEEDS_BALANCE | Missing or stale current-source qualification |
| tag_hunt | NEEDS_BALANCE | Missing or stale current-source qualification |
| base_siege | NEEDS_BALANCE | Missing or stale current-source qualification |
| drift_floes | NEEDS_BALANCE | Missing or stale current-source qualification |
| duo_clash | NEEDS_BALANCE | Missing or stale current-source qualification |

Reports: `/tmp/kras-evidence-natural-report/report.json` and
`build/party/content-audit.json`; the latter is a regenerable local output.
Commands and runtime logs are retained under `/tmp/kras-evidence-natural*`
and `/tmp/kras-evidence-audit-final*`. Re-run the audit after simulation source
changes; do not treat this dated snapshot as live release approval.

The fingerprint covers source/data/scenes/tools and project.godot, not native
binaries, visual/audio assets, test files, signing profiles or an iOS archive.
It supplements, never replaces, frozen Git checkout/build source proof.
Physical iPhone/iPad orientation, input compositions, thermal/frame-time QA,
human playability, AI fairness review, current server/client production rollout
and exact-source signed archive remain separate requirements. No main merge,
Railway deployment, Apple upload or review submission occurred.

## Tool And Runtime Qualification

Focused policy suite:551 assertions pass. Initial malformed-count tests exposed
invalid cross-type comparisons in the new policy implementation; numeric type
and completeness guards now precede comparisons. Final stdout runtime/test
guards pass. Logs: `/tmp/kras-evidence-policy.stdout` (initial failure) and
`/tmp/kras-evidence-policy-final.stdout` (passing).
Full source gate:394 scripts,366297 assertions,439 resources with zero inventory
issues, authored race/boss regressions and39 stability matches with zero failures.
`/tmp/kras-evidence-gate.stdout` records its detailed evidence directory.
No gameplay balance parameters were changed in this tooling patch.

## Full Campaign Dispatched

GitHub accepted run37484382887 from exact source
`e5bd09499448b92b4cdc26b5d890526e156c3cc8`, development branch
`fix/kras-balance-evidence-provenance`, seed offset1500000. At verification it
was queued, not completed. No earlier campaign existed on this branch, and no
other run was cancelled. Expected coverage:39 games,24 baseline plus16 paired
difficulty plus2 smoke matches per game,1638 matches total, maximum3 workers.
Do not dispatch again merely because queued execution is slow.

Run: https://github.com/shary17454/kras-pass/actions/runs/37484382887
Completion, artifact source/checkout, pairing and outcome review still need
verification. A successful workflow is not automatically READY for the store.
