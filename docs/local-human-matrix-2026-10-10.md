# Automated human-configured lifecycle matrix

## Scope and implementation

Gameplay source remains `73a2ea97fa361a74ab03dc8d9b56e1f2be530e25`.
This phase changes the QA tool, its shell wrapper/fixtures and CI artifact list,
not player movement, minigame rules, scores or AI difficulty.

`tests/stage_zero_stability.gd --human-matrix` runs all 39 games with human
counts 0, 1, 2, 3, 4 and remaining slots configured as gameplay Bots. Human
slots retain human configuration, Touch input sources and their normal HUD.
Explicit QA pilots generate ordinary input frames through InputRouter; the
TouchSource physics publisher is disabled during this automated test. Pilots
are not registered as gameplay Bots. A pulsed action starts human instruction
cards through the normal input transition; no forced phase transition is used.

This is NOT physical touch, gamepad hardware, four actual people or human
playability acceptance. It does exercise human-configured lifecycle branches,
Touch source ownership, mixed human/Bot setup, result handoff and cleanup.

## Verified results

- One matrix cycle: 39 games x five human counts = 195 matches, exit 0,
  no recorded failures. Every game/count pair occurs exactly once.
- Each row reports terminal phase DONE and returns to baseline 51 scene nodes.
  Baseline orphan count is zero. Existing checks verify weak-reference release,
  global signal counts, detached input sources and empty shared match services.
- Default mode compatibility: three cycles, 117 four-Bot matches, exit 0,
  no failures. Report human_counts=[0], synthetic_touch_pilots=false.
- Default post-warmup static memory growth: 945544 bytes, under the unchanged
  16 MiB limit. Memory-warning settling: 267413879 -> 145190419 bytes.
- Matrix single-pass settling: 272658511 -> 152085703 bytes. This single pass
  does not establish sustained-growth behavior. Neither run returned static
  memory to its cold baseline; do not infer zero leaks or device thermal/FPS QA.
- Both successful stdout logs pass the strict runtime guard.
- Final compile check: all 450 scripts compile, exit 0, runtime guard PASS.

Timed rounds are shortened to five seconds; actual race laps remain unchanged.
The first/default arena per game is covered, not all map variants, orientations,
pause/restart permutations or all possible arrangements of human seats.

## Failed attempts retained

The first new-tool attempt compiled but aborted before matches because a ternary
produced an untyped Array assigned to Array[int]. The confirmed failed process
was stopped with SIGINT (exit 130), then corrected with typed Array.assign.

The next attempt completed 195 cases with 156 human-case failures: QA pilots
did not press Start on instruction cards. The production game correctly waited
for human input. The tool was corrected to publish ordinary action pulses;
no production rule or failure threshold changed. Both failure logs and the
156-failure JSON report remain alongside the successful evidence.

## CI integration and evidence

`tools/check_party.sh` now runs a separate one-cycle local_matrix check after
the existing stability check. `game-quality.yml` retains its JSON artifact.
Wrapper regression verifies exactly one matrix invocation, normal success,
18 general failure cases and failure of the matrix itself. Shell syntax,
workflow YAML syntax and git diff checks pass. This new CI configuration has
not been pushed or executed remotely; fixture tests are not real Godot runs.

Persistent evidence: `../qualification-human-matrix-2026-10-10/` with original
stdout/engine logs, matrix-pass.json, default-pass.json and failed-matrix JSON.
Temporary successful reports remain in `/tmp/kras-human-matrix-ready-save/`
and `/tmp/kras-human-matrix-default-save/`.

No READY/DONE promotion, main merge/push, Railway mutation/deploy, new native
archive, App Store upload or review submission. Canonical current-source balance,
full network completion/current-source qualification, device QA and approved
production/release gates remain open.
