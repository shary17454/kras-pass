# Current-source natural simulation and expanded network snapshot

## Source and scope

- Date: 2026-10-10. Local branch: `feature/kras-online-random-rotation`.
- Runtime source: `5b07018a6358368a6cddc0f6ec68f2cd617df55d`.
  The three later commits present when the run started changed documentation only.
- Godot: `4.7.1-stable (official)`; isolated runtime: `/tmp/kras-tank-pursuit-check`.
- Pre-run, post-run and current checkout simulation fingerprint:
  `c6997498a03697a4c59d66bb1cf99ef2016098bc982dcaf88ace346df6e1cf81`.
- This fingerprint covers selected source/data/scene/tool extensions and
  `project.godot`, not native code, imported assets or the signed release archive.

## Completed supplemental balance campaign

The process completed with exit 0 in 2424.9 seconds. Both stdout and engine log
passed the existing strict runtime log guard. Before the run, the existing
balance-policy suite completed 7643 assertions and passed its test-summary guard.

- All 39 registered games: 24 baseline matches, 16 paired difficulty comparisons,
  two mutator/chaos smoke matches each: 936 + 624 + 78 = 1638 completed instances.
- Baseline/difficulty windows match declared game durations; races retain their
  lap behavior. Mutator/chaos smoke uses the shorter existing smoke window.
- Four AI players, each game's first/default arena; not all map variants.
- Seed offset: `40000000`. All recorded baseline and paired seeds validated.
- Roster policy: `seeded_partition_seat_rotation`. Every character appears
  twelve times per game, three times in each of four seats. Paired comparisons
  use identical seed/character with mirrored Expert seats.
- All 39 smoke rows completed both modes with no error flags.
- Existing boss objective/comparison verifiers accepted all four bosses:
  baseline defeated/survived: Forge 24/0, Colossus 20/4, Dreadnought 24/0,
  Sovereign 24/0. No unknown outcome. Smoke survival is not a boss defeat claim.

Warnings are retained: `tank_arena`: Expert point share 0.5125, below the existing
0.52 separation threshold; `lab_crates`: character bias 0.25. These are small-sample
review signals, not proof that one character is globally overpowered.

This is supplemental evidence, not the canonical campaign. The existing official
aggregator requires `adjacent_rotation` and individual campaign manifests;
neither policy nor acceptance thresholds were changed. Previous campaign warnings
remain applicable to their own source/cohort. No READY or DONE promotion occurs.

## Expanded network snapshot

Downloaded 23 artifacts from run `38022898755`: Core plus 22 network games.
Network artifact manifests match checkout/intended commit
`c0a5b6c6d3b9cb0875c47aa9c87c5ada1ce39b9c`, run ID and clean tracked state.
This older source does not qualify the later race-crate pickup fix automatically.

Verified 88 match/tournament groups for two/four humans, 276 peer logs with
completed markers and passing strict runtime guards, agreement on scores,
round history and tournament state, host/client transport restoration, and
completed tournaments. The six final `moved=false` records all correspond to
`spectator=true` in the final round, where the player is not a contender. The
test enforces movement for active contenders. An initial over-broad read-only
audit that required movement from spectators failed; the actual contract and
round records were inspected, without changing production or test code.

Games: blast_ball, color_stand, crate_relay, crate_smash, crumble_court, gem_grab,
goal_guard, hurdle_dash, magnet_court, mnatiq, mukharrib, paint_grid, quick_draw,
relic_hold, ring_rumble, rising_tide, sky_court, star_rush, storm_heart,
symbol_echo, tag_hunt, zone_hold. This is a snapshot, not completion of all 39
network jobs, nor proof of production Internet/device behavior. The bounded
shared-champion fallback documented in the earlier snapshot remains unchanged.

## Evidence and remaining gates

Persistent evidence: `../qualification-current-natural-2026-10-10/balance/`
(JSON, HTML, stdout, engine log, progress), and `network-expanded/` (artifacts).
Original temporary paths remain `/tmp/kras-c699-all39-natural-report/` and
`/tmp/kras-network-c0-38022898755-expanded-snapshot/`.

No runtime changes, main merge/push, Railway migration/deploy, archive rebuild,
App Store upload or review submission in this phase. Local feature commits only.
Still required: investigate warning cohorts, canonical current-source campaign,
complete network campaign, real-device QA/energy measurements, approved production
backup/restore and rollout, then exact-source Xcode 27 archive and Apple gates.
