# Local iOS release integration - 2026-11-21

## Source and scope

- Repository: `shary17454/kras-pass`; remote: `origin`.
- Production base: `main`, `23d29f40f1b7dd735b4bb1840bc0b57d0a98cd79`.
- Release branch: `release/kras-ios18-xcode27-20261121`.
- Integrated feature chain: `fix/kras-menu-readability-20261026`,
  `b3c01b54de14fb0fb971b50109bf4e48acd4f6dd`.
- That chain contains `integration/kras-app-features-2026-10-18`
  (`d796003a99e9528424fd715364a03c320e09b976`), including the reviewed
  local/online tournament, input, AI, replay, daily challenge, audio,
  appearance, camera, HUD and server-validation improvements.
- The merge preserves the production endpoint changes from main. The only
  textual merge conflict was build 110 versus 111; 111 was retained pending
  live verification and selection of a new release number.

The qualified candidate uses protocol 2 at the same production host's
`/multiplayer/v2` route. Production retains `/multiplayer` for protocol 1
clients, with isolated room/session registries and shared resource limits.
This avoids replacing the current store client's protocol during rollout.
Native WebSocket routing tests cover both handshakes, room isolation, ready,
start and resume. They do not constitute execution of App Store build 111.

## Branch selection

There were 232 remote branch heads: 132 were not ancestors of main, and 120
of those were already included in the integration chain. They must not be
merged independently again.

Excluded separate heads:

- `feature/kras-local-xcode27-candidate-112`,
  `release/kras-local-candidate-111`, and
  `release/kras-local-xcode27-candidate-109`: historical build numbering,
  not additional gameplay features.
- `docs/kras-current-core-and-signing`, `docs/kras-device-qa-build-421114d`,
  `docs/kras-independent-balance-review`,
  `docs/kras-main-049e660-qualification`, and
  `docs/kras-replay-retention-production-qualification`: qualification of
  older source snapshots, not proof about this release.
- `fix/game-library-touch-scroll`, `fix/kras-blast-victim-ties`, and
  `test/kras-performance-config-validation`: equivalent changes are
  documented in the existing branch integration audit. Do not replace later
  fixes with these older variants. A fresh `git cherry -v` against integration
  marked each unique patch equivalent (`-`): `c880a5f`, `c7a34c5`, `3f2cb52`.
- Rejected `experiment/*` behavior must not be reintroduced. Historical
  diagnostic commits already in the integration ancestry are not a request
  to re-enable their rejected runtime changes.
- Cloud-export branches are not release candidates. The local pipeline
  rejects Xcode Cloud and the legacy Cloud hooks fail closed.

## Platform policy

- Minimum deployment target: iOS 18.0, including the native bridge.
- Local toolchain: Xcode 27 or newer; this Mac was checked as Xcode 27.2.
- Bundle ID: `com.shary.kraspass`; Apple team: `4HM66AD594`.
- Use the installed Apple Distribution identity. Do not import P12 files,
  reveal credentials, or create/revoke certificates.
- Godot Control layouts, responsive containers and safe-area conversion
  provide the game UI. Native UIKit appearance/layout applies separately to
  native overlays and the launch screen; adding a second SceneDelegate is
  not a substitute for verifying Godot's generated lifecycle.

## Acceptance gates - not yet a release approval

1. Review all merge changes and pass final parsing/unit/integration checks.
2. Resolve `network-zone_hold` without weakening its behavior assertions.
3. Test compact portrait, both landscapes, iPad, Duo closed/open and window
   resizing, Arabic/English and light/dark/system appearance.
4. Test iOS 18 startup and guarded newer UIKit APIs; distinguish simulator
   results from physical-device touch, thermal, battery and fold tests.
5. Confirm current App Store Connect builds, set Version/Build, commit and
   push the final source, then tag only a qualified candidate.
6. Generate fresh engine pack and native bridge from that source, archive
   locally, verify embedded identity/version/build/profile and codesign.
7. Upload, wait for processing, choose the exact build, configure automatic
   release, submit, and verify the resulting review status separately.

Do not merge to main or trigger account database migrations without a
verified production backup and restore plan. A local migration test is not
a backup of production. The user approved an encrypted production snapshot
on 2026-11-21. It was encrypted inside Railway before transport, saved outside
Git in a private local directory, and independently restored and checked.
Source/snapshot schema and content hashes matched; integrity and foreign-key
checks passed. Migration 0 -> 2 passed on an isolated restored copy. Production
was not modified. Private artifacts and recovery keys must never enter Git.
The non-personal evidence and rollback plan are in the owner's qualification
directory (`main/production-backup-verification.json` and
`main/backup-restore-plan.md`). Refresh that snapshot if deployment is delayed;
the backup and recovery key currently share one Mac. This release branch has
not deployed Railway.

At initial inspection, App Store Connect showed 1.1.11 (111) available and
automatic release selected for that existing version. Its setting does not
prove the next version's release option. The session later required login.
The disk fell to 118 MiB and a build-tool installation failed with ENOSPC;
resource import was stopped. After the desktop restart, space was 242 GiB
and the temporary checkout had disappeared. All retained patches were
recovered into the persistent `kras-release-20261121` checkout, and checks
were rerun. No user files or prior archives were deleted by this task.

The App Store Connect API independently confirmed the bundle identity and
latest uploaded build 111. The next candidate is 1.1.12 (112); this is a
source configuration, not evidence of an upload or submission.

## Current validation

- Godot parsing: 474 scripts, PASS.
- Complete Godot suite after the portrait hint correction: 516,780 assertions,
  PASS. The prior run's 140 failures all concerned that hint offset and were
  fixed in runtime, not by weakening the assertions. Persistence/router error
  injection is intentional in their recovery suites.
- Server suite including versioned protocol routing: 290 tests, 284 PASS,
  0 FAIL, 6 SKIP because external captured-world fixtures were not supplied.
- Production dependency audit: zero reported vulnerabilities.
- Local iOS pipeline: 23 tests PASS; export evidence: 24 tests PASS; Node log
  and simulator architecture guards: 7 tests PASS.
- Native bridge: device arm64 and universal simulator compilation PASS with
  minimum iOS 18 and guarded iOS 27.1 reserved-region APIs.
- Appearance capture: 1,971 assertions PASS and settled-frame screenshots
  inspected; this is desktop Godot evidence, not an iOS renderer/device test.
- The original Zone network seed passed twice in isolated real-peer runs,
  six matches in total. Prior contention/timing failures are retained in the
  Zone report; CPU causality is not proven and no runtime scoring was changed.

The player-count stability matrix also passed: 195 completed matches, all 39
default arenas with human counts 0, 1, 2, 3 and 4, no result/cleanup failures,
and a clean strict runtime log. Timed rounds were shortened; race laps were
unchanged. Inputs for human slots were synthetic pilots, not physical touches.
One cycle does not establish long-term device memory or energy behavior.

The installed engine's simulator library was independently checked as x86_64
only. Duo runtimes require arm64; metadata listing arm64 cannot supply a missing
slice. A matching simulator engine must be built or obtained before claiming
Duo simulator execution. The existing device-arm64 template is a separate
artifact and is not being replaced by that simulator work.

Fresh native archiving, iOS runtime QA, production deployment and Apple
upload/review gates remain separate steps.
