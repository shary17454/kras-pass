# Ice surface batching qualification - 2026-10-09

## Change and source

Based on commit `3e83904c9143834f183fcddd317ddec60da6dbaf`, this change batches the 60 decorative ice cracks, patches and scratches into 14 MultiMesh nodes. It keeps the original cached rounded-box meshes, dimensions, bevels, materials, transforms and shadow policy. No collision, rules, player movement, AI, quality setting or particle budget is changed.

Runtime fingerprint after the shipping change: `1f990ad6a3691bc4b9bd1b9dd32aefca026c74a76ac9d2ad68de2bc25689e52b`.
Prior runtime fingerprint: `4bcd0fb2fc4db5dd8df1c02b31065b182d12db0282d66ab61071eb9b7c982ed2`.

## Tests

- Full headless regression: 392980 assertions passed in 177 seconds; strict log guard passed.
- Focused headless tests: 153 assertions passed. Dummy rendering does not return actual MultiMesh instance transforms, so these tests check authored batch data and the renderer instance schema, not GPU placement.
- Focused Metal tests: 153 assertions passed using actual instance transforms, independently compared with the original authored formulas at radii 12 and 19.
- Rendered Arabic orientation smoke: ring_rumble, fawda and sweeper_storm; portrait and landscape; one touch human and three bots; six captures, zero failures. Runtime log guard passed. This is not full catalogue or physical-device QA.

The visual run uses its own positive capture summary, not the unit-test summary expected by the log guard's `tests` mode.

## Before/after observation

Godot 4.7.1, Metal Mobile, Apple M5, 1920x1080, seed 11, four Expert bots, uncapped rendering without VSync, ten simulated seconds per run. Both runs exited successfully and returned to 51 nodes after cleanup.

| Metric | Before | After |
| --- | --- | --- |
| Authored decoration nodes | 60 | 14 |
| Draw calls at physics frame 513 | 1526 | 1434 |
| Draw calls at physics frame 803 | 1517 | 1425 |
| Mean frame ms | 16.70 | 16.73 |
| P95 frame ms | 17.00 | 16.93 |
| Worst frame ms | 43.81 | 43.73 |
| Final static memory MB | 158.4 | 158.2 |

The approximately 6% draw-call reduction is real in this sample. A meaningful frame-time or stutter improvement is NOT established. Cold rendering spikes remain. This does not prove 120 FPS, physical iPhone performance, battery usage, thermal stability or absence of leaks.

The real screenshots were inspected. Geometry remains present and nonblank, but transparent draw ordering makes some white patches more visible; weather particles also differ. The screenshots are not pixel-identical.

## Release gates

Chrome's authenticated App Store Connect page for Kras Pass (6801506973) was inspected on this date. The latest chronological visible upload is 1.1.10 (107), Complete. No 1.1.11 upload was visible.

The locally signed Xcode 27 archive for 1.1.11 (110) was built from **3e83904**, before this change. It must not be uploaded as containing these latest changes. A fresh frozen-source archive is required after the intended release source is approved and committed.

Existing immutable balance/core CI runs pinned to 3e83904 do not qualify this new runtime fingerprint. Preserve their results; do not relabel them. Physical-device QA, production qualification and outstanding product/balance gates remain separate. No upload or review submission was performed.

## Raw evidence

Logs, before/after images and the capture report are retained outside Git in `../qualification-ice-batches-2026-10-09/` beside this checkout. Relevant files include `kras-ice-batch-full.stdout`, `kras-ice-batch-rendered-tests2.stdout`, `kras-ice-batch-before.stdout`, `kras-ice-batch-after.stdout`, `kras-ice-batch-visual.stdout` and `visual-report.json`.
