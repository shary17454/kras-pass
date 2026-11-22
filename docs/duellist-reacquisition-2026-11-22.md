# Duellist Reacquisition Delay

Baseline: 9b629317c1785ea5e3caf48dffbdb8caa30e4432.
Working branch: fix/round-persistence-ai-20261122.

The duellist selector checked current visibility and first-observation memory,
but did not use the shared continuous-visibility reaction gate. An opponent
seen earlier could disappear and become a movement target immediately upon
return, before the difficulty's reacquisition delay. The attack action had its
own gate; this finding does not establish hidden-position reads or perfect aim.

The selector now requires can_target() as well as existing sampled knowledge.
Keeping the second condition preserves the no-unsampled-fallback contract even
when tests explicitly choose zero reaction delay. Last-seen history is retained.

Regression exercises all four difficulties, first acquisition, sampled and
between-sample occlusion, pre-threshold selection and prediction, exact-threshold
selection and resumed pursuit. Before the runtime change: 16 failing assertions.
After: all 4568 assertions in ai_visibility passed, exit 0, with the tests log
guard passing. The official engine was Godot 4.7.1 a13da4feb on local macOS.
Save data was isolated outside player storage.

Evidence outside Git, in the sibling qualification-quickplay-20261122 directory:
- ai-reacquisition-before.stdout and .log
- ai-reacquisition-after.stdout and .log

The preceding 112-baseline/56-difficulty/two-mutator duel diagnostic at seed
offset 105000000 retained a character-advantage warning. It predates this fix
and is not acceptance evidence for the new source. It also logged a sandbox
system-certificate startup error, so its terminal exit 0 is not a clean log
qualification. No threshold was relaxed and no balance warning was closed.

This patch is not an iPhone/Duo performance test, a complete all-game balance
campaign, a new signed archive, an upload, or an App Store review submission.
Build 113's archive and uploaded assets remain unchanged.
