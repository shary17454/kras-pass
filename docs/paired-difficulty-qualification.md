# Matched AI difficulty samples

The earlier difficulty loop alternated Expert seats while also changing the
world seed and character. That does not isolate seat bias: the paired conditions
were different. Comparisons now keep seed and character fixed within each pair
and swap only the Expert/Easy seat assignment. At least one mirrored pair runs
for every character. With 24 baselines this means 16 comparisons, plus two smoke
rounds: 42 matches per game, or 1,638 for the 39-game campaign.

Reports retain each sample's seed, character, Expert seats and completion.
The evidence validator verifies all eight characters, identical pair seeds and
characters, opposite seats and completed samples. `--paired` rejects legacy
unpaired reports. Legacy results remain readable but are never silently labelled
as paired evidence. Running campaign 37108335239 keeps its original source and
1,482-match policy; it has not been cancelled or restarted.

## Source And Checks

Runtime source: `826bb5ad8d4541e8f22b4245e868dc8477b2d30c`.
Compared 361 tracked Godot/source/data/test/tool files and project.godot with
the runtime checkout before the run: zero mismatches. Runtime was not modified
while the simulation ran.

- `/tmp/kras-paired-balance-policy.log`: 225 assertions passed, exit zero.
- `/tmp/kras-paired-balance-compile.log`: 324 scripts compile, exit zero.
- `/tmp/kras-paired-balance-server.tap`: 144 passed, zero failures/skips.
  Six world fixtures are from the earlier ball-delay source; this does not
  imply fresh final-source Godot network captures.
- Report validator: 24 tests pass, including seed/character/seat/completion/
  roster mismatch rejection and explicit legacy handling.
- Workflow YAML parsed; all seven embedded shell scripts pass bash syntax.
- `npm audit --omit=dev`: zero known vulnerabilities at the time checked.

## Actual Natural-Round Run

`/tmp/kras-paired-balance-draw.log`: Quick Draw, 24 complete baseline rounds,
16 complete comparisons and two successful smoke rounds. Exit zero,
1,061.3 seconds elapsed, mean baseline duration 75 seconds. JSON under
`/tmp/kras-paired-balance-draw-report/` confirms eight distinct characters,
matched pair seeds/characters and swapped Expert seats for all 16 samples.

This qualifies one game's execution and the measurement design, not all-game
balance. A new paired campaign is needed after the original campaign completes
and findings are reviewed. Final-source regression, device performance and
Apple release remain separate unfinished gates. Local Godot logs retain the
macOS system CA retrieval warning.
