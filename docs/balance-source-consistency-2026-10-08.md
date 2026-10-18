# Balance campaign source consistency

Code: `76737abdec1103a3c7f7778eaf3da66e6b1b336b`.
Parent: `2a252edc5a3c169aeaaacbd9f39723bcdbc26f66` (PR 208).
Only the JavaScript balance evidence aggregator and its tests changed.
No gameplay, balance threshold, AI profile, save schema, production server
behavior or Godot file changed.

## Reproduced qualification gap

The aggregator checked commit, checkout, run, game coverage, natural windows,
seeds, mirrored difficulty and boss outcomes, but ignored the simulator's
start/end source fingerprints and engine identity. Nine regression cases
demonstrated acceptance of missing/malformed/changed/mixed fingerprints,
missing/wrong engines, and an explicit different expected source pin.
Parent RED: 59 passed, nine failed.

The corrected aggregator requires a canonical SHA-256 fingerprint, equality
between simulation start/end, equality across all observed games, and the
expected engine (`4.7.1-stable (official)` by default, matching the pinned
project toolchain). An explicit expected fingerprint must also match.
CLI option: `--source-fingerprint=SHA256`.

Summaries expose the observed source fingerprint and engine. Source consistency
is not marked complete when games are missing, and empty partial evidence does
not invent a verified source or engine. Release readiness remains false;
source consistency alone does not establish balance, polish or device QA.

Focused GREEN: 78 passed. Includes positive matching-pin controls, partial and
empty evidence controls, and rejection of malformed expected pins/engines.
Full server suite: 224 passed, zero failed/cancelled/skipped, using six actual
Godot captures from `kras-party-check.aebtpa/saves-tests`. Those runtime inputs
are unchanged from PR 207; this is not a new Godot full-gate run.
Logs: `/tmp/kras-balance-source-consistency-red.log`,
`/tmp/kras-balance-source-consistency-green.log`,
`/tmp/kras-balance-source-server-tests.log`.

## Actual artifact checks

The old campaign's 37 downloaded reports pass the stronger checker with an
explicit old-source pin:
`d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e`.
Their source commit is `82f3a7692b8f61b341fb26d69b3170c3a82496cd`, run
37694780646, offset 1200000. They prove 1554 natural matches; drift_floes and
duo_clash remain missing. Their Crumble/Magnet seat and Scrap difficulty
warnings are retained. Both campaign completion and source consistency remain
false because the expected 39-game coverage is incomplete.

The same actual reports are rejected (CLI exit one) when pinned to the CURRENT
simulation source:
`65e6139b1d2b87e38898b3386623671d87bed40db1d78baf803a58ff08b79807`.
An independent Node reproduction of the existing Godot fingerprint algorithm
hashed 274 files in src/scenes/data/tools and project.godot with the exact
existing extension policy and reproduced that current fingerprint. This is a
simulation-source stamp; it excludes other assets/native signing inputs and
is NOT an archive, PCK, Apple signature or device-performance attestation.

Raw partial summary and the three newly downloaded old-source game reports:
`docs/qa/balance-source-consistency-2026-10-08/`.

## Compatibility and running campaigns

Legacy reports without valid source fingerprints/engine can no longer qualify;
their historical files are not deleted or rewritten. Regenerate missing
evidence instead of fabricating the fields. Existing real Godot 4.7.1 reports
remain supported. An intentional engine upgrade needs an explicit expected
engine change; this patch does not upgrade Godot.

Current-source campaign 37709226998 is alive on exact source
`b8efc5131ea3b47b4c20dabdb04463414e1b7264`, offset 1200000.
Its catalogue completed and 39 simulations were queued at this checkpoint.
It does NOT run this newer aggregator code. Revalidate its artifacts with the
stronger checker and explicit current pin before accepting them. No running
campaign was cancelled or restarted due to quiet output. The modified .mjs
and tests are outside the existing simulation fingerprint extension/root
policy; current simulation inputs remain byte-identical to that campaign.

## Uncompleted release

All-game current-source balance/perception/polish, intermittent network timing,
physical iPhone/iPad QA, approved production backup/migration/promotion/deploy
and Internet/auth acceptance remain. A fresh local Xcode 27 Distribution
archive and independent signing/upload/processing/App Review verification are
still required. No main merge, production operation, new archive or Apple
submission was performed by this change.
