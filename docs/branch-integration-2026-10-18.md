# Branch integration audit - 2026-10-18

Status: full local gate passed; integration branch pushed; Linux CI pending.
No promotion to production main and no store publication.

## Repository and source

- Repository: `https://github.com/shary17454/kras-pass.git`, remote `origin`.
- Default branch: `main`, verified through GitHub repository metadata.
- Inspected main: `66efebee5e8c68c2071a13b2a7a7d6c6c06b521e`.
- Development source: `0a65aa4d820fd5e04f4d4f3ac0581d19ac6ab6e8`.
- Built application source: `0251a2e9dcfde36821adbf678c2274b1b0cc7850`.
- Final test source: `9596a2983e93936e2e4b2b1b158485aa6ec59514`.
- Working branch: `integration/kras-app-features-2026-10-18`.
- Isolated checkout: `/tmp/kras-branch-integration-2026-10-18`.

The original `kras-qualified-current` checkout was clean and on
`feature/kras-online-random-rotation` before isolation. It was not checked out,
reset, cleaned, stashed, or overwritten. The older sibling `kras-pass` has
offloaded iCloud Git metadata; its local `main`, `feature/kras-online-release`,
and `feature/kras-pass-multiplayer-framework` refs were inventoried by path but
their tip contents could not be verified. Those files and work were left alone.
The audit is complete for the 230 advertised remote branches, not a claim
that unreadable unpublished work in that older checkout has been recovered.

`main` is also named in the checked-in Railway GitHub source and main-push CI.
The iOS pipeline exports the current Godot checkout through `tools/export_ios.sh`
and builds the `KrasPass` scheme; it is not technically restricted to one branch.
The external App Store Connect/Xcode Cloud workflow configuration was not
queried or changed. The current installed/store binary's source is not inferred
from a branch name or an old checked-in Xcode project.

## Branch decisions

The machine-readable inventory records every remote name and full tip hash,
ancestry, unmerged paths/commits, and the review decision:
`branch-inventory-2026-10-18.json`.

Initial ancestry classification: 100 tips already in main, 117 more included
by the development source, and 13 requiring individual review.

Merged into the isolated integration branch:

1. `feature/kras-online-random-rotation`: accumulated original application,
   multiplayer, tournament rotation, local input, AI, replay, daily challenge,
   camera/HUD, original audio and appearance fixes. The single main-only
   documentation commit was preserved by an actual two-parent merge.
2. `fix/kras-railway-plan-integrity`: refuses unreported networking, service,
   tracing, build and runtime changes and preserves declared production
   networking/runtime. These are source/validator changes only; no plan/apply,
   secret, database copy, volume change, or production deployment was executed.
3. `fix/kras-main-qualification-continuity`: preserves main/manual CI runs.
   One conflict in `game-quality.yml` was resolved by retaining both immutable
   source runs and separate core/tank/balance diagnostic groups. PR revisions
   can still cancel their superseded runs.

Not re-merged because `git cherry` verified equivalent patches already exist:

- `fix/game-library-touch-scroll`: the unnecessary inner ScrollContainer is
  already gone; favorites and the current responsive library were retained.
- `fix/kras-blast-victim-ties`: seeded equal-distance target choice already
  exists, with newer perception gating retained.
- `test/kras-performance-config-validation`: invalid game/arena/duration/
  quality rejection already exists, with newer vehicle workload checks retained.

Excluded from this integration:

- `feature/kras-local-xcode27-candidate-112`,
  `release/kras-local-candidate-111`, and
  `release/kras-local-xcode27-candidate-109`: only historical build-number
  changes, not missing features. No new store build number is reserved here.
- `docs/kras-current-core-and-signing`, `docs/kras-device-qa-build-421114d`,
  `docs/kras-independent-balance-review`, `docs/kras-main-049e660-qualification`,
  and `docs/kras-replay-retention-production-qualification`: historical reports
  for different exact sources. They do not certify this integrated tree and add
  no runtime feature.

The three `experiment/kras-*` tips are already historical ancestors of the
development source. Their tips explicitly reject the proposed driver backoff,
ram-alignment and crumble-route policies and restore the prior runtime. Their
rejected policies were not resurrected or separately merged. Historical raw
logs and rejected patch files are retained as evidence, not applied as code.

## Integration repairs and reachability

- The online screen existed in the router but had no main-menu entry. Added
  its localized menu action without enabling an unqualified production service.
- Added real button-driven navigation checks in Arabic/English, portrait/
  landscape, with configured and unconfigured endpoint states. The latter
  retains the existing explanation and usable local-play fallback.
- Fixed a real boss HUD regression: the shared text backing set a shrinking
  horizontal flag on an autowrapped caption, collapsing it to 17 pixels. The
  caption now fills its header. A controlled portrait probe reduced occupied
  height from 862 to 316 pixels, retaining the original 35-percent screen gate.
  Expanded the four-boss test across both appearances without relaxing the gate.
- Corrected the paused-settings regression to count the arena's actual
  callbacks and check total listener recovery after closing the appearance
  selector. A legitimate selector callback is not a duplicate arena listener.
- Reproduced the Zone Hold CI tournament failure at seed `1082281558` locally.
  Waiting input fixtures previously travelled to far ring arcs before a six-
  second capture turn. Staged them just outside the zone with separated waiting
  positions. No production game, duration, AI, physics or scoring change was
  made; every participating peer must still actually capture and agree on scores.
- Retained both new and existing test script identities generated by a fresh
  Godot import, so the exported/source-evidence gate does not encounter
  untracked script UID dependencies.
- Existing settings expose persisted system/light/dark appearance, independent
  music/SFX options, performance and touch customization. Existing local party,
  tournament, adventure, training, library, daily and replay routes are retained.
- The online room browser is reachable but production online availability is
  not falsely switched on. Local WebSocket tests do not certify an Internet
  deployment, production authentication, or four physical devices.

## Verification

Toolchain: Godot `4.7.1.stable.official.a13da4feb`, local Xcode 27.1
(`27A9275`), iPhoneOS SDK 27.1, Node 24.18.0. No Xcode Cloud execution.

Completed checks at this checkpoint:

- All 468 scripts compile; inventory: 575 resources, 22 autoloads, 27 routes,
  8 characters, 39 game definitions, zero structural issues.
- Infrastructure: 29/29 passed, including the newly merged plan protections.
- Server: 276 passed, zero failed and zero skipped, using all six captures
  generated by the final integrated Godot suite.
- Full unit/integration suite: 446,644 assertions passed on `9596a29`.
- Actual race regression and all six seeded boss checks passed. The 39-game
  AI stability sweep completed with zero failures. The full 0-4-human matrix
  completed 195 matches with zero failures using synthetic touch pilots.
- Export evidence: 24/24 Python tests passed.
- Export/simulator/Godot log guards: 15/15 Node tests passed.
- Wrapper success and injected-failure checks passed; shell syntax passed.
- Resolved workflow parses as YAML. Runtime/source whitespace check passes;
  preserved historical raw logs/patches contain whitespace and were not rewritten.
- Previous Zone Hold failure seed `868246213` passed locally with two peers,
  score capture for both, identical results `[5,1,5,6]`, and guest/host reconnect.
  This is a macOS rerun, not proof the prior Linux failure was fixed.
- Targeted boss HUD: 285 assertions; live shadow/settings: 115 assertions;
  zone driver/world: 4,785 assertions. All passed their strict log guards.
- Final application appearance: 627 rendered assertions, 34 screenshots,
  Metal mobile renderer. Four actual boss games: eight live captures across
  both orientations, zero visual-check failures. Desktop, not device evidence.
- Two-peer Zone Hold tournament at `1082281558` now completes all three rounds
  with both humans scoring in each and identical host/guest standings. Four-
  peer Zone Hold at `438683058` completes with scores `[15,14,11,9]` and matching
  results, including host/guest reconnect. A separate mixed four-peer no-repeat
  tournament completed three games with identical championship accounting.

The first integrated full suite on `117d5a2` reproduced the same nine failures
as Linux (eight boss layout cases and one aggregate-listener assertion). A
subsequent full rerun on `0251a2e` was deliberately interrupted before editing
the newly reproduced network fixture; it is not counted as a pass. The full
final regression/stability run on `9596a29` passed every stage, including the
195-match human matrix, and exited zero. The reproduced Zone Hold tournament
seed is now explicitly pinned in Linux CI as well. Subsequent changes are
workflow and documentation only, not runtime or test fixture changes.

Linux core run `39095885401` was dispatched on exact source `9596a29`; its
in-progress status is not reported as success. Previous source run
`39093201293` failed core and Zone Hold and is retained as pre-fix evidence.

## Local iOS build

`tools/export_ios.sh device` completed a fresh unsigned Release-iphoneos build
using local Xcode 27.1, not Cloud. Export/build source was a clean detached
checkout at `0251a2e9dcfde36821adbf678c2274b1b0cc7850`.

- Identifier: `com.shary.kraspass`; version/build: `1.1.11 (110)`.
- Binary: arm64, iPhoneOS SDK 27.1, deployment minimum iOS 15.0.
- Device families: iPhone and iPad; portrait and both landscape orientations.
- Source export stamp recorded and `ios_export_evidence.py verify` passed.
- App: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/tmp.pU17pAhIo9/Build/Products/Release-iphoneos/KrasPass.app`.
- Project/export: `/tmp/kras-ios-integration-export-2026-10-18`.
- Build diagnostics: `/tmp/kras-ios-integration-build-logs-2026-10-18`.

`git diff --exit-code 0251a2e 9596a29 -- src scenes assets data native
project.godot export_presets.cfg` verified the subsequently changed test driver
does not alter any built application inputs. The exact build is still attributed
to `0251a2e`, not silently relabelled with a later commit.

Known iOS-only GDExtension-not-found diagnostics occur when the macOS exporter
inspects the static iOS extension. They were retained by the dedicated export
guard and are not called a clean editor log. Native compilation succeeded;
runtime launch on iOS, signing, archive, and distribution were not performed.

Evidence prefixes: `/tmp/kras-integration-*-2026-10-18.*`. Full Godot evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.pFpK2m`.
The earlier failed complete run is `kras-party-check.zMTBNP`.
The first sandboxed import logged a system CA-access error; the subsequent
local import completed cleanly. Sandboxed server socket tests returned EPERM;
the authorized local rerun passed. Neither failure was hidden as a green run.

## Remaining gates

- Confirm all relevant current Linux CI jobs, including the prior Zone Hold
  regression, rather than treating a local successful seed as a universal fix.
- Before promoting migrations to Railway-connected main, verify a durable
  production database backup/restore path. Synthetic migration tests are not
  an actual production backup.
- iPhone/iPad: four-person touch ergonomics, both orientations, physical
  controller disconnect, actual native auth/purchases, FPS, battery and thermals.
- The stability sweep uses shortened timed rounds and synthetic human input.
  A single cycle does not prove a long-session memory plateau or device FPS.
- The older iCloud checkout's unpublished local branch tips remain unverified.
- No archive signing, App Store upload, review submission or approval is claimed.

Durable local evidence copy (outside Git):
`/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-branch-integration-2026-10-18`.
This includes native screenshots and build/network/server evidence. Generated
logs and images are not added to the source repository.
