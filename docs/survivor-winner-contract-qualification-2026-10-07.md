# Survival Winner Contract

Runtime/test commit: `e07a540289624a583edcb558f0db90824c8a409b`.
Branch: `fix/kras-survivor-winner-contract`, based on dash projection.

## Reproduction and Repair

Scrap Karts declares that the last kart running wins. A coherent four-player
sequence (P1 wrecks P2/P3, then P0 wrecks P1) instead yielded scores
`[12,14,2,4]` and winner P1, who had already been eliminated.

Regression before repair: 33 assertions passed, four failed, exit 1;
`/tmp/kras-survivor-red.stdout`. Each possible last survivor lost to the
eliminated hunter in a four-player match. The two/three-player cases passed.

The shared survival result now applies a common score lift to surviving slots
only when necessary to put every survivor above every eliminated player.
Knockout counters and bonuses are preserved, as are relative scores among
survivors and among eliminated players. No lift applies when everyone is alive
or everyone has been eliminated. The custom simultaneous-water scoring uses
the same invariant. No character, AI profile, impulse, balance threshold or
declared rule was changed.

Expanded regression: 42 assertions pass (2/3/4 players, every survivor slot,
repeatability, timeout with multiple survivors, tied survivors, all eliminated,
and retained knockout statistics). Water scoring: seven assertions pass,
including same-tick elimination ties and a high-KO eliminated rival losing to
the survivor. Both strict log guards pass.
Logs: `/tmp/kras-survivor-expanded.stdout`, `/tmp/kras-survivor-tide.stdout`.

## Full Qualification

The first full gate `/tmp/kras-party-check.IMHZBi` FAILED at inventory because
three imported scene resources were not yet generated. It is not a successful
gate. The initial editor import was stopped (exit 130); identical unchanged
asset import cache was copied from the parent worktree, then the editor import
was rerun and completed exit 0. No asset source or rendering setting changed.

Fresh full gate: `/tmp/kras-party-check.lbdq8e`.
Compilation: 418 scripts. Inventory: 517 resources, 22 autoloads, 27 routes,
eight characters, zero issues. Unit/integration suite: 388724 assertions pass
in 252.5 seconds. The actual three-lap race, all six explicit defeated-boss
checks and 39 stability matches pass, with zero stability failures. Overall
command exit 0 and all stage log guards pass. Settled texture/material/mesh/PCM
caches are zero; process memory is 140305980 bytes. This is one cycle, not a
long soak, phone FPS, battery or heat qualification.

Server integration initially failed under sandbox with `listen EPERM` on
127.0.0.1 (`/tmp/kras-survivor-server-tests.log`). It was rerun with approved
local loopback access, using all six new engine captures from lbdq8e:
204 pass, zero fail/skip, exit 0, 901.8 ms;
`/tmp/kras-survivor-server-tests-local.log`. No production account or database
was accessed. npm audit reports zero known dependency advisories at inspection
(`/tmp/kras-survivor-npm-audit.json`); that is not overall security certification.
The known macOS CA diagnostic and intentional save/route/memory-warning fixtures
remain visible. No log guard or test was relaxed.

## Natural Balance Remains Open

Two natural samples each completed 24 baseline matches, 16 matched-seed and
matched-character difficulty matches, and two short mutator smoke matches.
The smoke rounds are not natural-duration balance evidence. Strict logs pass.
Independent Node validation confirms counts/seeds/all eight mirrored character
pairs and matches the source fingerprint across 272 files:
`bb391fb77305db702f2ecc5438de81703adfab4859fc0cf4e3c5a4056de9f290`.
Both reports have identical start/end fingerprints.

| Seed offset | Expert share | Character bias | Slot bias | Tie rate |
| --- | --- | --- | --- | --- |
| 1200000 | 0.49375 | 0.0833333 | 0.1666667 | 0 |
| 1500000 | 0.5125 | 0.0833333 | 0.0833333 | 0 |

Both retain `expert bots no better than easy`, `balanceReviewComplete=false`
and `releaseReady=false`. Correcting the winner is necessary but does not
establish fair difficulty balance or completion of the whole product.

Raw committed reports:
`survivor-contract-scrap-natural-1200000.json`, SHA256
`89951bc99dfa35d16782bb4c8e9fc4b144fc4c0cd05975fdad379a91b15d986e`;
`survivor-contract-scrap-natural-1500000.json`, SHA256
`d897d7f8ae8a05e54571c768d63045e5e80f087b01340c76bf93e7ce5dc65050`.

## Release Boundaries

No main merge, protected database action, Railway rollout, phone installation,
new archive, upload or App Review submission. Existing archives predate this
repair and are not valid sources for this release. Remaining work includes AI
balance and targeting review, current affected-game qualification, native
device controls/performance/auth/subscriptions, production acceptance, and a
new frozen-source local Xcode 27 Distribution archive before Apple submission.

The existing remote campaign was read, not restarted or cancelled: run
37616445234 had 22 completed jobs and an active hurdle_dash job at inspection.
It qualifies an older commit, not this repair.
