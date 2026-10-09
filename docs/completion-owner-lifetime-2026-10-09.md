# Match Completion Owner Lifetime

Parent: `16c74008fe6f925a3e08c0b7bc676490c7fa3368` on
`feature/kras-online-random-rotation`.

## Reproduced Shipping Failure

A real daily Start button opened the routed match and the simulation completed
naturally. With a different local profile active, results appeared but the
original owner's record still had `completed: 0`. The callback target had
already been freed: a Godot Callable does not retain its RefCounted owner.
The fallback results path masked the lost daily completion callback.

The actual UTC challenge was `20261009`: base_siege / iron_flats, turs,
easy bots, slow_motion, seed 134811129. Natural result: 28.0666667 simulated
seconds, scores [0,2,0,41], places [3,2,3,1]. No winner, score, duration or
round count was injected. The human instruction card was acknowledged through
an engine-local keyboard event; the rest of the match ran normally.

Earlier test attempts are retained but rejected: the first waited too few
accelerated frames for threaded preparation; the next supplied no human
instruction acknowledgement; one diagnostic dereferenced the missing target
and emitted a script error despite exit 0. They are not passing evidence.

## Correction

MatchScene retains a RefCounted completion owner during setup, while the
launching router coroutine still holds it. Teardown clears both the Callable
and owner. It does not retain freed Node callbacks, invent results or change
scoring, input rules, seed, physics, match time or AI.

After correction, the identical natural daily result records one completed
attempt and best score 0 for the original owner. The other active profile
receives no daily record or claim. The launching screen is freed, two rapid
Start activations count once, and routing ends with one screen.

Focused full-flow test: 15 assertions, exit 0. Lifecycle suite: 24 assertions,
exit 0, including a temporary callback target surviving its caller and being
released at teardown. This specifically tests ownership, not just callback
validity while the fixture keeps its own strong reference.

The committed flow regression freezes this UTC schedule in the launch fixture
so it does not turn into an idle-human race test on a future date. Daily UTC
selection is tested separately. The match simulation, rules, scoring, roster,
duration, result callback and routing are the shipping implementations.
The full regression on the shipping correction passed 393904 assertions in
187.9 seconds, exit 0. It used the actual UTC schedule above before this
test-only fixture stabilization; the focused stabilized flow is rerun below.

Stabilized focused flow: 15 assertions, exit 0. Compilation: all 437 scripts
pass. Each final full/focused/lifecycle/compile log passes the existing Godot
checker independently; `git diff --check` passes. Sandbox CA errors and
intentional negative-test diagnostics remain in raw logs, not removed.

Runtime fingerprint:
`71b5a52a33d4be33e306e93acdc777fdf3b7de41c82e8e463cbc88bd7901ed7c`.
Evidence directory: `../qualification-completion-owner-2026-10-09/`.

## Scope And Release Limits

This is a shared lifecycle correction, not completion of the original 146
requirements or phases 0-50. Weekly challenge implementation is still absent.
Current-source all-game balance/network qualification, physical-device play/
energy acceptance, production integration and an exact-source local Xcode 27
Distribution archive remain required. The live c1-source campaigns remain
their original-source evidence and have not been cancelled or restarted.
No main merge, production database operation, device installation, archive,
upload or review submission occurred in this correction.
