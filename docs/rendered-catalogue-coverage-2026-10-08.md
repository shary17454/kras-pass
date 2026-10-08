# Rendered Catalogue Coverage

The previous rendered `--all` sweep used `Registry.minigames()`, which deliberately excludes adventure bosses from ordinary match rotation. It therefore measured 35 games, not the full 39-definition catalogue. Its raw filename contains `all39`; that filename is not coverage evidence.

## Correction

`tests/perf.gd` now selects `Registry.all_minigames()` for `--all`. Argument selection is extracted into `_configure_games` so the exact selection path is tested without opening a window. Explicit `--games=a,b` still overrides the sweep. No production rotation, gameplay, stats, renderer, timer or sampling threshold was changed.

Regression test: before the correction, five failures (35 instead of 39, plus each missing boss); after the correction, 94 assertions passed in the focused performance suite. Runtime log guard and diff whitespace check passed. Local macOS reports its known CA-store error during headless initialization; this was not a GDScript failure and the log is retained rather than called error-free.

Full regression run: 392828 assertions passed in 181.5 seconds, exit 0; strict test-summary/runtime log guard passed. The test save directory was isolated from user data.

## Supplemental Rendered Measurement

Local Godot 4.7.1, Metal Mobile, Apple M5, 1920x1080, Dummy audio, VSync disabled, uncapped drawing. Runtime fingerprint before/after: `4bcd0fb2fc4db5dd8df1c02b31065b182d12db0282d66ab61071eb9b7c982ed2`. Base commit: `0e8ff30ac4186b10e9e7cb9be752f75530eebbc9`, plus the two test-file changes described above. This is not an archive from that commit.

Command: `tests/perf.tscn --games=boss_forge,boss_colossus,boss_dreadnought,boss_sovereign --prepare-resources --slow-frame-trace`, isolated test data, actual rendered window, no fixed FPS.

| Game | Mean / p95 / worst (ms) | Full budget |
| --- | --- | --- |
| boss_forge | 16.79 / 17.35 / 64.69 | Yes |
| boss_colossus | 16.70 / 17.44 / 36.14 | Yes |
| boss_dreadnought | 16.67 / 17.28 / 18.12 | No: round ended after 9.25 live seconds, 495 post-warmup samples |
| boss_sovereign | 16.66 / 17.38 / 18.15 | Yes |

Exit 0, runtime log guard passed, nodes after cleanup 51 / starting 51. These results complement, not replace, the previous 35-game run: union coverage 39, full budgets 36. sky_court timed out; hurdle_dash and boss_dreadnought ended early. The retained slow-frame correlations do not establish a cause. Shared Mac pacing is not physical-device FPS, energy, thermal or long-term leak qualification.

## Evidence and Remaining Gates

Raw RED/GREEN and supplemental rendered logs: sibling workspace directory `qualification-perf-catalogue-2026-10-08/`. Prior run: `qualification-rendered-0e8ff30-2026-10-08/`. These files are outside the repository to avoid shipping bulky generated evidence.

No current-source balance approval, physical iPhone/iPad/controller qualification, production Railway rollout, signed Xcode 27 archive, upload or review submission is inferred. Existing permissions and distribution gates remain unchanged.
