# Crater Clipping Qualification

## Source And Scope

Runtime/test commit: `12511c00ac45b4492c1eb2ae4356ab6aa59af2f0`.
Branch: `perf/kras-crater-clipping-bounds`.
Base: main `3c6db5816857df68c7900fdd86c9ca445a2a2904`.
This branch is not automatically merged into main.

Crater floor rebuilding previously clipped every remaining polygon against
every hole in all 128 sectors. The correction computes one conservative
axis-aligned bound per hole and sector and skips cuts only when those bounds
are disjoint. All remaining pieces are subsets of their original sector.
Touching bounds and a 0.001-unit rounding margin retain exact polygon clipping.
Sector count, 48-point cut geometry, radius quantization, rendered normals/UVs,
collision ownership, shrink timing, physics and match rules are unchanged.

## Geometry And Timing Evidence

The focused `crater_clipping_bounds` suite passed 97 assertions and its runtime
log guard. It compares the optimized floor with the same pipeline forced to
retain every cut. Cases include uncut ground, center/off-center holes,
overlapping holes, a rim intersection, a completely removed floor, a remote
nonintersecting hole and twelve distributed craters, at radii 16 and 8.

For every case the suite checks triangle count and carved surface area and
compares actual physics ray intersections on a 35-by-35 grid plus 96 near-rim
probes per hole. Rendered vertices match collision faces exactly. A comparator
initially assumed identical triangle ordering; repeated polygon clipping may
rotate vertices and retriangulate a polygon without changing its surface.
Acceptance therefore checks physical coverage and area rather than assuming
that triangulation order is a gameplay invariant.

One off-center crater retains 52 of 128 clipping candidates (76 skipped).
Twelve repeated twelve-crater rebuilds gave median 11144 microseconds with
all cuts retained versus 3139 microseconds with conservative bounds on this
Mac headless run. The reference still computes bounds, so this comparison
isolates filtering, not a separately compiled historical engine/source build.
Timing is diagnostic, not a fragile pass/fail threshold or phone FPS claim.

Focused log: `/tmp/kras-crater-bounds-focused-engine.log`.
An initial invocation omitted an explicit writable engine log and crashed in
Godot's user-log initialization. The explicit-log rerun completed. Sandboxed
macOS CA-access diagnostics remain separate from gameplay test results.

The frozen runtime completed `GODOT_BIN=/opt/homebrew/bin/godot sh
tools/check_party.sh` with exit 0. Artifacts:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.8UK3wI`.
All 385 scripts compiled. Inventory reported 425 resources, 21 autoloads,
27 routes, eight characters and zero issues. The full suite passed 360739
assertions in 215.2 seconds, followed by the real three-lap race and six boss
regressions. Stability completed 39 default-arena matches with zero failures;
ordinary windows are shortened and this is not full natural balance coverage.
Five-second settled Godot static memory was 441318784 bytes with 183 resources;
retained memory is unresolved and this is not phone RSS/GPU evidence.

Actual localhost `network-smoke.js --game=boss_colossus --humans=2
--seed=438683058` completed with exit 0 and a passing runtime guard.
Two Godot peers plus two bots moved, host and guest reconnected, and both
reported scores `[1020,550,0,30]`, with 3196 guest world snapshots. Existing
boss damage/defeat/crater replica assertions were retained. Server event-loop
maximum was 144 ms, not a latency qualification. Log:
`/tmp/kras-crater-bounds-two-peer.log`; artifact directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-ga2RxR`.
`git diff --exit-code 12511c00ac45b4492c1eb2ae4356ab6aa59af2f0 -- src tests`
confirmed the runtime and tests were unchanged after both runs.

## Prior Colossus Cooperation Evidence

These natural samples tested the parent runtime
`b2348bef6ddfa591beffeaea222aea885b16d081`, now included in main, NOT this
new clipping optimization. Both reports completed 24 baseline matches,
16 mirrored difficulty matches covering all eight characters and two stress
matches with the authored 150-second boss window retained.

| Seed Offset | Baseline Defeats | Baseline Survived | Mean Seconds | Expert Share |
| --- | ---: | ---: | ---: | ---: |
| 600000 | 3 | 21 | 146.4493 | 0.6550 |
| 900000 | 2 | 22 | 149.1646 | 0.6550 |

All 32 mixed-difficulty matches defeated the boss. Both mutator and chaos
matches in each sample survived rather than defeating it. Seed identities,
boss outcome counters and mirrored character/slot pairs were checked; no
unknown outcomes. Empty automated flags do NOT establish adequate difficulty
or READY status. Baseline victory remains low and needs further balance and
human-play review. The previously traced medium seed 609001 still did not
defeat the boss after the correction; that failure remains evidence.

Reports:
`/tmp/kras-colossus-cooperation-natural-report/report.json`,
`/tmp/kras-colossus-cooperation-independent-report/report.json`.
The parent full pipeline passed 360643 assertions, race regression, six boss
regressions and 39 shortened-window stability matches. Parent localhost
two-peer play/reconnect passed with matching scores `[1075,305,165,55]` and
3481 guest worlds; server-loop maximum 242 ms is not latency qualification.

## Current Production And Release Gates

Fresh Railway inspection confirms deployment
`d08dd7a0-246f-4af0-89b2-520a7eebccef` SUCCESS from GitHub
`shary17454/kras-pass`, main
`3c6db5816857df68c7900fdd86c9ca445a2a2904`.
`/health` returned `ok=true`, `authentication_ready=true`,
`multiplayer_enabled=false`. Six returned deployment log entries were info,
with no error-level entries in that sample; this is not full API/DB/auth QA.
The clipping branch has not been deployed to production.

Main Game Quality run `37390678273` was queued at inspection for the exact
main commit. Prior main run `37386716943` was canceled after the subsequent
push; its completed core artifact is historical evidence, not a successful
full matrix for current main or this branch.

The latest inspected App Store version was 1.1.10, build 107, Ready for
Distribution; no source commit is inferred from that existing build.
No new archive, signature verification, upload or review submission occurred
during this change. Remaining release gates include physical iPhone/iPad
orientation/performance/thermal/battery QA, unresolved balance/pacing,
retained memory, production Internet multiplayer and an exact-source signed
Xcode 27 Distribution archive with fresh version/build verification.
