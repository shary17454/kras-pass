# Duel Player Visibility: Candidate For Parent Review

> Historical stage-one record. The subsequent physics-callback correction,
> 385 focused assertions, native Metal Mobile/Forward+ images and separate live
> results are documented in [the current handoff](duel-player-visibility-handoff-2026-11-22.md).

## Identity And Scope

- Worktree: `/private/tmp/kras-duel-visibility-20261122`.
- Branch: `fix/duel-player-visibility-20261122`.
- Base HEAD: `ff0f9aaa6b2d5bb0c8dd91508fc28fbb3bc443c7`; no commit, push or merge made.
- Production changes: `src/camera/arena_camera.gd`, new `src/camera/arena_occlusion_fader.gd`, and elevated-body tagging in `src/arenas/arena.gd` only.
- No Fighter, rules, AI, collision, vertices, authored transforms, spawns, input, save, profile, replay, data JSON or renderer project settings changed.

## Observed Failure, Not Yet A Rendered Improvement Claim

The supplied original [h1 Arabic portrait](</Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/melee-rendered-ff0f9aa/native-20261122-01/h1-ar/save/screenshots/duel_pit-portrait.png>) and [h4 Arabic portrait](</Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/melee-rendered-ff0f9aa/native-20261122-01/h4-ar/save/screenshots/duel_pit-portrait.png>) visibly hide player bodies behind elevated supports. The original pit has 7+8+9 ledges at y=2.3/4.6/6.9 and a summit at y=9.1. The ground pips do not establish body visibility; the existing Fighter comment that nothing occludes a pip is not a valid invariant and was not edited outside this worktree's ownership.

No new native window or screenshot has been produced. Seeing four actual bodies after the change, live gameplay readability, and Mobile/Forward+ GPU cost remain unverified. A headless pass is not rendering evidence, and no physical iPhone claim is made.

## Presentation Contract

- Only the existing elevated pit bodies are tagged; their own child meshes are the permitted fade targets. Floor, rim, collision geometry and node layout stay unchanged.
- `camera_occluder_alpha` is read as an optional ArenaDef parameter. Its runtime fallback is 0.12 for `duel_pit`, zero for every other arena. Setting the parameter to zero disables and restores it immediately.
- **Deliberate catalogue preservation:** adding the opt-in to `data/arenas.json` was rejected and undone before Godot ran. `PartyPlaylist.catalog()` hashes that file's raw bytes, which are also used for saved-plan validation and daily-record identity. Activation is therefore runtime-only in the presentation code, not a persisted schema/catalogue edit. No progression compatibility policy was widened.
- Camera-to-body/head rays use world mask 1, bodies only, and no gameplay writes. Each sample inspects at most four input targets, two points each, and six intersect calls per point: at most 48 queries per sample. Samples are throttled to no more than 10 Hz, with no catch-up bursts. Untagged geometry stops traversal.
- Each eligible StandardMaterial3D is duplicated on the first cache miss, never per frame. Only the duplicate gets `TRANSPARENCY_ALPHA` and positive alpha; immutable textures and original materials are shared, never mutated. A cached duplicate is reused across repeated occlusions. Cache size is bounded at 64, above the default pit's 25 meshes and maximum authored ledge-count recipe's 49.
- Unknown shaders, overlays, multiple surfaces without a mesh-wide standard override, multipass materials and pre-transparent materials fail closed rather than having art replaced with a fabricated material.
- Unoccluded bodies restore the exact previous material override, including null. Camera reconfiguration, disable and exit clear references and restore materials. A replacement by another material owner is not overwritten by cleanup.
- Positive alpha is clamped to 0.08..0.35 times the source alpha. Existing AIBrain classifies positive-alpha terrain as a visible occluder; its state, code, world masks and decisions are not modified. The focused test explicitly compares AI observation before/after, including active unchanged colliders.
- Transparency may change shadows and alpha ordering: those are visual effects to inspect on Metal, not assumed benefits. No camera framing, camera collision avoidance or target eligibility logic was replaced.

Godot documents that [GeometryInstance3D transparency is ignored by Mobile/Compatibility](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-transparency). This change instead uses the [BaseMaterial3D alpha pipeline](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#enum-basematerial3d-transparency); renderer suitability still requires actual Metal screenshots and measurement.

## Actual Verification And Retained Failures

Evidence root: [kras-duel-visibility-evidence-20261122](/private/tmp/kras-duel-visibility-evidence-20261122).

1. First Node source audit: 4 passed, 1 infrastructure failure (`git show` buffer overflow while reading an unrelated large screenshot). The source comparison was restricted to tracked source/data/tests/project files; the corrected five source-contract tests passed. These are not engine assertions.
2. First wrapper invocation failed before launching Godot because the output parent did not exist. Recursive output-parent creation was corrected. It did not consume a simulation or native capture.
3. [import-01](</private/tmp/kras-duel-visibility-evidence-20261122/import-01>) reached terminal exit 0, but both strict log guards rejected an actual GDScript inference error at the new ray-point declaration. It is retained as failed, not reported as a successful compile. The declaration was made explicit. The before/after source evidence also records six generated UID files and no changes to previously hashed files; initial import is not a stable-source test pass.
4. [unit-01](</private/tmp/kras-duel-visibility-evidence-20261122/unit-01/result.json>): 310 assertions, exit 0, stable source, both log guards 0.
5. [unit-02](</private/tmp/kras-duel-visibility-evidence-20261122/unit-02/result.json>): 379 assertions after adding cache-capacity and capture-script compilation coverage; exit 0, stable source, both log guards 0.
6. [unit-03](</private/tmp/kras-duel-visibility-evidence-20261122/unit-03/result.json>): **380 assertions**, exit 0, stable source, both log guards 0, official engine banner `4.7.1.stable.official.a13da4feb`. This is the final tested code; source hashes are pinned in its `source-before.json` and `source-after.json`. No full suite was run.

Final hot-path observations from [unit-03 stdout](</private/tmp/kras-duel-visibility-evidence-20261122/unit-03/stdout.log>):

| Fixture | Actual Observation | Limit |
| --- | --- | --- |
| Three stacked real physics blockers | 8 ray queries/sample, 3 copies total over 61 samples; final sample 16 microseconds | Cache misses only allocate |
| Adversarial mocked ray responses | 4 targets scanned, 48 calls; observed sample 271 microseconds | 48 calls/sample, no catch-up |
| Oversized 70-mesh candidate set | 64 cached copies; freed mesh pruned; clear releases clone weak references | 64 entries |
| Focused fixture cleanup | 51 nodes before, 51 after | No retained extra nodes |

The microsecond values are single desktop **headless CPU fixture** observations, not a statistical benchmark, GPU timing, sustained frame time, Metal cost or mobile performance qualification. The worst-query fixture mocks intersect results to prove loop bounds; it does not benchmark worst-case physics. Partial alpha can increase overdraw on Mobile, so actual renderer/performance review remains mandatory.

## Deferred Native Gate

The slot permission was for focused headless work only. Native GUI must wait for additional permission after Feynman's GUI window is finished. Do not run both native methods together, do not fake GPU features and do not substitute a software backend.

The prepared `tests/duel_visibility_capture.tscn` uses the real arena and four real fighter visuals at authored static spawns. It explicitly labels itself **static_visibility_not_live_gameplay**, freezes only that fixture's simulation, and captures exact same-position/camera before/after pairs for h1/h4, Arabic/English, portrait/landscape. No silhouette/mask is substituted for bodies. Nonblank pixel checks alone do not certify four visible bodies; every row requires visual review. The capture script's GDScript compilation passed in unit-03, but it has not been executed.

After permission, run stages separately with fresh output directories:

```sh
node tests/run_duel_visibility.mjs --slot-authorized --stage=tests --output=/private/tmp/kras-duel-visibility-evidence-20261122/unit-new
node tests/run_duel_visibility.mjs --slot-authorized --stage=capture --method=mobile --output=/private/tmp/kras-duel-visibility-evidence-20261122/mobile-new
node tests/run_duel_visibility.mjs --slot-authorized --stage=capture --method=forward_plus --output=/private/tmp/kras-duel-visibility-evidence-20261122/forward-new
```

The wrapper records command, engine/stdout logs, terminal state, source before/after and strict log guards; it refuses an existing output, duplicate own Godot process, or occupied three-worker capacity. The capture script requires actual Metal and the requested rendering method and refuses headless/software/fallback capture. None of those commands authorizes itself; parent slot permission still governs execution.

Then acquire **separate live** foreground gameplay evidence with production pause/background guards intact and compare player bodies, not just pips. The static fixture is not a substitute. Parent review, native renderer images, live gameplay and measured GPU/frame-time review remain open. `renderedImprovementVerified=false`, `physicalDeviceQualified=false`, `releaseReady=false`.
