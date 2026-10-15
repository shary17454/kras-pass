# Circuit start-depth correction - qualification remains open

The authored circuit grid placed slots 2 and 3 another 1.6 metres behind the
line on every match. Circuit starts now share one longitudinal depth, with
four laterally spaced positions constrained by road width. No character,
physics, AI, item, scoring, duration, or warning-threshold tuning changed.
This corrects a geometric head start; it does not prove overall spawn balance.

## Regression and physical-road evidence

The existing race-round suite now builds all eight authored circuits and
checks four spawns, equal start depth, chassis separation, road-edge clearance,
and actual ray intersection with each map's FantasyWorld/RoadCollision.
The original temporary slab is replaced by that physical road, so tests must
not mistake its absence for missing collision.

- RED: 227 passing assertions, 16 failing equal-depth checks (two per circuit).
- GREEN: 243 passing assertions, no failure; strict log check passed.
- Compile: all 442 scripts loaded; strict log check passed.
- Full regression: 403978 assertions passed in 257.0 seconds; strict log
  completion/error checks passed. This includes real AI race completion across
  maps, but is not exhaustive physical-device or every human-input acceptance.
- Desktop renderer: four Arabic captures across kart_sprint/sabaq_sawarikh
  and portrait/landscape, with four scripted touch slots; zero failures.
  The two armed-race screenshots were visually inspected. These are desktop
  screenshots, not four people playing on an iPhone.

## Matched natural campaigns: not qualified for release

Both campaigns use seed offset 6000000, the same 120 actual baseline seeds
and roster arrays, unchanged adjacent_rotation policy, 60 paired difficulty
matches, and two stress matches. Each completed 182 matches with a stable
source fingerprint. Total actual campaign matches here: 364, not thousands.

| Measurement | Before | Equal-depth grid |
| --- | --- | --- |
| Slot wins | 32, 32, 33, 23 | 32, 20, 42, 26 |
| Character wins barq/fanoos/ghaim/mowja | 34/11/20/10 | 29/14/18/13 |
| Character wins nabta/ramla/sakhra/turs | 28/9/4/4 | 25/7/7/7 |
| Average simulated seconds | 129.2957 | 129.5304 |
| Expert edge | 0.70 | 0.70 |
| Baseline tie rate | 0 | 0 |
| Warnings | character advantage | spawn slot advantage; character advantage |

Before fingerprint:
`3a16b55a32738308c520239edd6f907c30c77a7de6dbf6060fecb3b0098981b2`.
Equal-depth fingerprint:
`8fb78fb08fb0f7665cf3e668219e27bd433df2e517c4b92a80310d5db9ae0257`.

The larger original-grid sample did not repeat the earlier 24-match slot
warning. The equal-depth candidate has a lateral slot warning and retains a
character warning. Do not suppress those warnings, call the game READY,
infer causality from these counts alone, or promote this candidate to main.
Follow up on lateral start allocation and character/roster effects. The
separate oval used by kart_sprint still has a two-row grid; that is not fixed
by this circuit-only change.

## Real multi-process networking

Four real Godot processes plus a local WebSocket backend completed the armed
race at seed 6009614. All four results matched (18792, 18359, 18255, 18199);
host and one guest restored their identity after disconnect. Exit 0. This is
scripted local-process network evidence, not Railway/Internet/device proof.

The older full-network CI campaign 37890891082 for 19f21be reported a
tank_arena failure: its three-contender final saw shots and inventory, but no
armor damage. The unchanged tank scenario passed when reproduced locally,
with real damage and one champion. That pass does not resolve the CI failure;
keep the failure logs and investigate the intermittent smoke driver/collision
path. No observer requirement was removed and no rerun masked the failure.
Last observation: 37 completed jobs, tank_arena failed, four jobs nonterminal.

## Source and release boundary

Parent commit: `6a10598a29b69016a86f58966759d010ab5f0054`.
Tested source/test patch SHA256:
`39b2ac4796eef2d396fdc0fb8726e58b6bb399f752073279f21a31be09e9a773`.
Raw reports/logs are retained outside the checkout at
`../qualification-race-equal-grid-2026-10-09/`.

The local Xcode 27 archive from 6a10598 predates this shipping-source change
and must not be uploaded as containing it. Final accepted source requires
affected checks and a new attested export/archive. No main merge, production
Railway migration/deployment, IPA upload or App Review submission occurred.
Full original product requirements, current-game qualification, production
backup/restore approval and physical-device acceptance remain open.
