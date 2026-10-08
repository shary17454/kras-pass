# Dodger edge-triggered jump retry

Parent: a71f373 on feature/kras-online-random-rotation.
Dodger held JUMP between decisions even though Fighter consumes just_pressed.
A grounded fighter could consume the edge during freeze and never receive a
fresh edge after freeze expired while the same incoming threat persisted.
The request now uses the existing one-physics-frame tap mechanism. There is
no new input buffer, automatic air jump, bypass of freeze or reaction policy.

Actual-floor regression failed on the original implementation: 67 passed,
one failed. After the one-line change: 68 assertions passed. The fixture
settles a real CharacterBody3D on a real StaticBody3D, uses the same InputFrame
edge semantics as the router, and confirms both no jump during freeze and a
retry after expiry. All 430 scripts compile; strict focused-test guard passes.
Full regression also completed: exit 0, 392746 assertions, 228.0 seconds;
strict full-test and compile log guards passed. This is not device FPS or
energy acceptance.

Matched natural comparison: independent seed offset 4500000, 96 baseline,
48 mirrored difficulty and two stress matches per source, all completed.
The baseline seed arrays are identical; both sources have stable start/end
fingerprints and pass their strict runtime guards. Original fingerprint:
60f1593289845db427c28f101db97776b0848643f427edcb32caf276c606bb7e.
Candidate fingerprint:
4bcd0fb2fc4db5dd8df1c02b31065b182d12db0282d66ab61071eb9b7c982ed2.

Both reports retain character advantage. Sakhra wins 24/96 and Nabta 3/96
in both. Candidate Mowja/Turs wins are 20/15 instead of 19/16. Expert share
is 0.56964656964657 instead of 0.575883575883576. This is a correctness repair,
not a proven difficulty/balance improvement or READY qualification.
Mean duration is about 32.28 instead of 31.20 simulated seconds.
The macOS system-CA lookup diagnostic remains in these logs.

Raw evidence: ../qualification-dodger-jump-retry-2026-10-08/.
Unchanged baseline: ../qualification-sweeper-expanded-4500000-2026-10-08/.
Campaign 37828743787 remains running on immutable source 4c3fd7a with the
original fingerprint; it was not cancelled, restarted, or relabelled as proof
of this changed Dodger. All-game/current-source and physical-device acceptance
remain required. No main merge, production deployment, signing, Archive,
upload or App Review submission occurred.
