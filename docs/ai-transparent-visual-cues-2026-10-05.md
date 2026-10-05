# Transparent AI Visual Cues

## Source and Behavioral Boundary

Runtime commit: `4ffe139`; corrected fixture and final tested source:
`0db18d4ddaa183eaa079e5218bd99763874f433f`.
Base: `18778f06ff137401c868e44b3b38e6c0a0f694d4` on main.
Branch: `fix/kras-ai-transparent-visual-cues`. No automatic main merge.

Compound actors previously remained observable when all mesh surfaces used a
zero-alpha StandardMaterial3D. Their active collision proxies also occluded
targets behind an entirely transparent wall. The focused baseline reproduced
three failures with 19 passing assertions (`/tmp/kras-transparent-before.log`).

Observation and world occlusion now share material-aware mesh eligibility.
The check respects mesh-wide overrides, active surface overrides, mesh surface
materials, visible overlays and additional material passes. It excludes known
zero-alpha MIX materials using ALPHA or ALPHA_DEPTH_PRE_PASS transparency.
Partially transparent and opaque materials remain cues. Surface traversal is
bounded to 32 and additional passes to four; unknown coverage remains eligible.

This does not attempt to infer custom shader/texture coverage, alpha-cutoff
patterns, particle emission or every authored logical marker. GeometryInstance3D
instance transparency is intentionally not treated as an iOS visibility rule:
[Godot documents that Mobile ignores it](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-transparency).
The selected material transparency behavior is documented in
[BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#enum-basematerial3d-transparency).
No difficulty, speed, RNG, protocol, scoring or production availability changed.

## Test Corrections and Exact-Source Results

The first expanded fixture attempted a self-referencing material next_pass.
Godot correctly rejects this before rendering: 25 passed and one failed in
`/tmp/kras-transparent-compound-final.log`. The corrected fixture uses a valid
five-material acyclic chain to exercise the traversal budget, not an impossible
engine state. Two unsupported suite filters selected zero suites and failed;
they are not counted as successful tests.

An initial full run started before the fixture correction and loaded the
corrected script later. Although its unit summary was green, it was stopped
(exit 143) and is not accepted as exact-source full evidence. The complete
replacement below ran without source changes throughout.

- Compound visibility: 26 assertions, exit zero, including camera-free
  observation, overlays, next passes and surface override precedence.
- Physics-ray occlusion: 21 assertions, exit zero, including transparent active
  collision walls, opacity restoration and associated sibling terrain meshes.
- `tools/check_party.sh`: exit zero on final source, 374 scripts compiled;
  414 resources, 21 autoloads, 27 routes, eight characters, zero inventory issues.
- 360348 assertions passed in 450.0 seconds. This wall-clock duration is longer
  than some earlier runs; its cause is not established or waived as a performance
  success. It is not a phone FPS measurement.
- Real three-lap regression and all six authored boss probes passed.
- Stability: 39 matches, zero failures in the one-cycle smoke.
- Node: 192 passed, zero failed/skipped, using all six newly generated world
  captures from this final gate.

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.lkV0KZ`.
Logs: `/tmp/kras-transparent-full-final.log`,
`/tmp/kras-transparent-compound-valid.log`,
`/tmp/kras-transparent-occlusion-final.log`,
`/tmp/kras-transparent-server-captures.log`.

## Actual Rendered Performance, Not Device Approval

Godot 4.7.1, Metal Mobile, Apple M5, macOS, 1280x720; final source above.
The other owned test processes had ended before this probe. Each game retained
over 500 frame samples and ten seconds of live simulation with all four fighters
moving. Log guard exited zero. These are three short desktop samples, not a
matched before/after causal performance experiment or physical iOS qualification.

| Game | Mean ms | p95 ms | Worst ms | Frames at least 25ms | Preparation ms |
|---|---:|---:|---:|---:|---:|
| tank_arena | 16.95 | 18.04 | 88.52 | 7 | 2561 |
| goal_guard | 17.04 | 17.61 | 126.00 | 9 | 84 |
| boss_forge | 17.04 | 17.29 | 104.94 | 6 | 349 |

Node count returned to 50, matching the start; this is not a long memory-leak
test. Forge recorded a 103.138ms frame while all probe pipeline compilation
counters were still zero. Compilation alone cannot explain every observed
spike. Goal Guard's worse short sample must not be presented as stable 60FPS.
Log: `/tmp/kras-transparent-rendered-perf.log`.

## Production Verification of the Base, Not This Branch

Railway deployment `b191d518-7c86-4fa2-b24b-b5e525274c8f` reached SUCCESS
for main commit `18778f06ff137401c868e44b3b38e6c0a0f694d4`.
Repository/branch: `shary17454/kras-pass`, main. The automatic deployment was
observed BUILDING then SUCCESS; no duplicate deployment was triggered.

The production health endpoint returned ok/authentication_ready true and
multiplayer_enabled false. The bounded 50-line startup log had no application
error, but retained Railway's Config-as-Code deprecation warning (existing
files supported until 2026-12-01). No IaC migration was applied.

Readonly production SQLite returned quick_check ok, zero foreign-key errors
and user_version zero. Boolean-only environment checks confirmed the intended
Apple client/team, owner, key presence/parseability and persistent database path.
No secrets or account records were displayed; no SQL/environment mutation.
The native account endpoint points to the production Railway URL. This is not
a fresh successful Sign in with Apple session from a Release app.

The physical iPhone16 Pro Max was unavailable in Xcode27 devicectl; simulator
entries are not substituted for thermal/battery/physical multiplayer evidence.
No installation, Archive, signature verification, upload or Apple submission
occurred. This branch is not deployed. Full release gates remain: unresolved
frame spikes and memory attribution, remaining perception/balance/content QA,
real 1-4 player device tests, four Internet peers/reconnect/host loss before
production online enablement, and exact-source signed release qualification.
