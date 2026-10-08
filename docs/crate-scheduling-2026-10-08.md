# Current Crate Smash scheduling diagnosis

Source: documentation-only descendant `023299f` of
`babcf829532f7882fcbe2f8dc81fa01299ede065`. Git diff between them is empty for
src, data, native, tests, server, project.godot and the quality workflow.
No source was edited while the run was live.

Command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot node
network-smoke.js --game=crate_smash --humans=4 --seed=3904242
--scheduling-probe`. This uses four actual Godot processes, scripted human
slots, the authored round duration, isolated test saves and loopback only.
The optional independent Node process has no gameplay or network work.

## Results and limits

The runner exited 0; all four strict runtime log guards passed. Scores agreed
at `[83,33,48,30]`; host and guest 2 reconnected. Guest snapshot counts were
3487/3508/3508. Different results from earlier real-time runs with the same
seed remain evidence that this fixture is not deterministic replay proof.

The server loop maximum was 599 ms. Both monitors retained 22 stalls, below
the existing 50-row cap. The largest server sampling excess was 576.076 ms
while loading (676.076 ms elapsed, 4.975 ms process CPU). The independent
monitor's largest excess was 425.755 ms (525.755 ms elapsed, 0.102 ms CPU).

For correlation, compare only excess-time intervals
`[startEpochMs + 100, endEpochMs]`, not the entire observation interval.
16 of 22 server excess intervals intersect an independent excess interval.
The six unmatched server excesses are 108.146, 103.746, 149.446, 132.694,
158.472 and 108.927 ms, with respective process CPU 0.634, 0.341, 0.746,
1.139, 1.165 and 3.035 ms. Neither cap saturated in this sample.

This is positive evidence of simultaneous cross-process timing delays,
unlike the older Scrap Karts runs where neither monitor retained a stall.
It supports investigating scheduling/shared machine load, but does not prove
a root cause or clear the six unmatched events. It does not repair or qualify
phone frame pacing, gameplay smoothness, public Internet or production.
No threshold, protocol, gameplay rule or server behavior was changed to
make the diagnostics pass. The earlier 334/762 ms results remain retained.

## Other checks

Fresh `npm audit --omit=dev --json` in server exited 0 and reported zero known
vulnerabilities. This checks registered dependency advisories, not application
authorization, secrets or runtime security. No package was updated.

Bounded timing reports, synthetic runner stdout and the dependency audit are
retained in `qa/crate-scheduling-2026-10-08/`. No raw saves or credentials are
included. Original temporary evidence: `kras-network-smoke-pJlC3m` under the
Mac's current TMPDIR.

Core CI `37768869605` still targets the exact `babcf829...` source. Its last
verified state was in progress; a successful server-test step does not prove
the whole run. No current-source all-39 balance/device acceptance, production
rollout, Apple archive/upload/processing or review submission is asserted.
