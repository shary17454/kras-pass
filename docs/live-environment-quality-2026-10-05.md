# Live Environment Quality Qualification

Implementation source: `85c91f79506091f59931e6326ccd914614b7675a`.
Parent: `9cba0c27921e2df6416e6c0a3f351cf560bf9f81`.

## Defect and Change

Environment effects were chosen only when an arena was constructed. Lowering
quality, enabling battery saver, or reducing effects in the pause/settings
screen retained SSAO, SSIL, SSR, volumetric fog and glow until another arena
was built. The settings service already changed FPS and resolution separately.

Arena now applies the same environment policy on construction and settings
changes. SSAO requires Forward+ and medium quality; SSIL, SSR and volumetric
fog require Forward+ and high quality. Reduced effects disables these effects
and glow; battery saver uses the existing effective reduced-effects policy.
Disabled effects are configured at construction so quality can increase live.

World-authored glow/volumetric-fog choices are explicit and preserved. Woodland
and its derived racing/tank worlds retain disabled glow and volumetric fog;
the fantasy circuit retains disabled volumetric fog. This does not rebuild
the Environment, sky, terrain, collisions, spawns or match context, or alter
world-authored exposure, fog color and lighting. No save/protocol changes.

## Focused Evidence

Godot 4.7.1 on macOS, isolated save directories:

| Check | Result | Log |
| --- | --- | --- |
| Pre-fix regression | 94 assertions passed, 13 failed | `/tmp/kras-env-quality-red.log` |
| Final headless regression/integration | 114 assertions passed | `/tmp/kras-env-quality-final.log` |
| Final actual Metal Mobile regression/integration | 114 assertions passed | `/tmp/kras-env-quality-mobile.log` |
| Compilation | 350 scripts passed | `/tmp/kras-env-quality-compile.log` |
| Complete Godot regression suite | 31,189 assertions passed, exit 0 | `/tmp/kras-env-quality-full.log` |

Completed-summary and script-error/leak log guards passed for final focused
checks and compilation. The red run additionally encountered sandbox system
CA access errors; its named quality assertion failures reproduce the defect,
but it is not an otherwise clean runtime. An earlier sandbox invocation
crashed before tests because its default user log was inaccessible; it is
excluded. Final checks used an explicit log and normal local system access.

Tests cover every quality tier, reduced-effects and saver toggles, an arena
created with saver already enabled, authored woodland lighting, fantasy-style
effect policy, resource identity, and real pause/settings controls followed
by resume. The actual settings integration uses controlled legal lifecycle
transitions, not natural multiplayer gameplay or physical touch interaction.

The full suite completed on the implementation source in 2546.7 seconds with
the positive completed-summary and runtime/leak log guard passing. It includes
all 39 game integration paths, pause/restart/device loss, paired AI difficulty
samples, authored terrain/bridge/tunnel assertions, and actual three-lap AI
finishes on all eight armed-race maps. Ordinary integration fixtures use short
round overrides; this is not an all-map natural-duration balance campaign.
Deliberate zero-assertion negative harness probes print two failure markers
inside their isolated probe; their rejection is itself asserted by the outer
suite, as in the independently verified parent CI. They are not suppressed.

A one-second, non-disruptive process sample was retained at
`/tmp/kras-env-quality-sample.txt`. Many native engine frames are unsymbolized;
it does not identify a causal performance bottleneck or prove a memory leak.
Full-suite wall time on this shared Mac is not a gameplay FPS benchmark.

## Independently Verified Parent CI

Run `37245701658`, core job `111563062683`, completed successfully.
Artifact source manifest:

- Intended head: `9cba0c27921e2df6416e6c0a3f351cf560bf9f81`.
- Checkout: `b4f82c42107f410de858160102e0767f38380ac3` (PR merge ref).
- Checkout tree: `07f336c1157e43d0e637c6d79beaa462d6ba5dda`.
- Parent local tree matches exactly; tracked changes empty.
- 31,155 assertions passed, 350 scripts compiled.
- 117 stability matches passed (five-second overrides, not natural-duration
  balance or all-map qualification).
- 192 server tests passed using actual Godot captures, zero skipped/failed.

Artifacts: `/tmp/kras-final-core-37245701658/`.
This evidence applies to the parent, not the new implementation commit.
Ring Rumble, Goal Guard, Relic Hold, Gem Grab, Star Rush and Zone Hold network
jobs also passed; the full network matrix was still running at inspection.
Zone Hold's source manifest matches the same checkout tree. Its retained
Linux seed `438683058` completed with two humans plus bots (scores `[0,0,6,0]`)
and four humans (`[25,0,0,0]`), matching on every peer, with host and one guest
reconnected. Its four-human tournament completed three matches with matching
points `[15,6,6,6]` and champion 0. This resolves the retained Linux seed's
no-score smoke failure on this parent source, not a general balance or real
internet latency claim. Evidence: `/tmp/kras-final-zone-37245701658/`.
Superseded runs `37244645861`, `37243562703`, `37241699301`, `37240170114` and
`37238857805` were cancelled after matching each live run's source and proving
it was an ancestor of the current CI source. All five were then verified as
completed/cancelled. Cancellation is not a successful test. The current run
was left intact.

## Release Gates Still Open

This is a live environment-cost correctness fix, not an FPS improvement or
a no-heat/no-battery-drain guarantee. Retained particles/weather and other
effect systems are not all made live-adaptive by this change. Physical
iPhone/iPad thermal, energy, long-session, local group and orientation QA,
the complete online matrix, all-map balance, production online enablement,
final-source Distribution archive/signature and App Store submission remain
separate gates. No main merge, Railway deployment, archive or App Store
upload/review submission was performed by this change.

Production health was read again during this qualification:
`https://kras-pass-production.up.railway.app/health` returned
`{"ok":true,"authentication_ready":true,"multiplayer_enabled":false}`.
This is health evidence only, not proof the new commit is deployed, not an
authenticated Apple login test and not an app-to-production device test.
