# Sweeper current-source expanded balance gate

Source: 0a48be6b424a0fd5ed5b0691a3907ad05dfce08d, branch
feature/kras-online-random-rotation. Runtime fingerprint matches the preceding
Blast repair and the newly dispatched full campaign:
60f1593289845db427c28f101db97776b0848643f427edcb32caf276c606bb7e.

Executed the existing natural runner, fixed 60 steps, 96 runs and independent
seed offset 4500000. No runtime, character, hazard, AI or threshold changed.
All 96 baseline, 48 mirrored difficulty and two stress matches completed;
exit 0 and strict runtime guard passed. Start/end fingerprints are identical.
The engine's macOS system-CA lookup warning remains in the log.

Results:

| Character | Baseline wins |
| --- | --- |
| Nabta | 3 |
| Sakhra | 24 |
| Fanoos | 14 |
| Ramla | 8 |
| Barq | 7 |
| Mowja | 19 |
| Ghaim | 5 |
| Turs | 16 |

Slot wins: 27, 19, 28, 22. Character bias: 0.125, flagged by the unchanged
sample-size-aware test as character advantage. Slot bias: 0.0416667, no slot
flag. Draw rate: zero. Expert placement-point share: 0.575883575883576.
Mean duration: about 31.2 simulated seconds. Both stress variants passed.

This independently reproduces the open character warning at a larger sample
on the current runtime. It does not prove a particular causal defect or justify
a speculative character nerf. The source review confirms own-capability jump
timing, delayed visible blade sampling, and common Fighter hit immunity;
their existence alone does not prove balanced play. Character style/weight,
control and accepted jump/contact timing still need a controlled comparison.

Raw report, HTML and log retained outside the repository in
../qualification-sweeper-expanded-4500000-2026-10-08/.
Full current-source campaign 37828743787 remains live on code commit 4c3fd7a;
this expanded report supplements it and must not be discarded if its smaller
24-run sample has no flag. No READY claim, main merge, production mutation,
Archive, upload or review submission occurred.
