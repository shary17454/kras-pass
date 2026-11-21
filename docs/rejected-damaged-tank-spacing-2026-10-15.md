# Rejected damaged-armor spacing candidate - 2026-10-15

Status: REJECTED; no gameplay or test change retained.
Stage 0 remains QA_PENDING / MERGE_PENDING.
Base: `0a578ab6fe462e7e87254702e1655acdc5001b12`.

## Hypothesis and candidate

The preceding hit-attribution campaign showed frequent stationary Expert victims
and early Expert-versus-Expert eliminations. Tested backing away from a visible,
forward target after own armor dropped to 75 or less, while more than two players
remained. The ordinary final duel, muzzle clearance and edge recovery remained.
Reverse input scaled with the existing strategy profile. No extra speed, damage,
ammo, hidden rival armor, unseen projectile information or scoring changes.

This is a hypothesis about engagement persistence, not a proven causal diagnosis.
Candidate fingerprint:
`a85fb27e5013e2ac067c347033b00608dcbc81d6bc16d7922aa74cb19c78465a`.

Expanded focused tests on unchanged gameplay: 81 passed / 4 failed. With the
candidate: 85 assertions passed and the strict test log guard passed. These
fixtures prove the intended input decision, not natural balance or fun.

## Matched natural campaign

```sh
godot --headless --fixed-fps 60 --path RUNTIME tests/balance_tank_trace.tscn -- --only=tank_arena --arena=tank_oasis --runs=112 --seed-offset=99000000 --out-dir=REPORT --test-data-dir=SAVE
```

Godot 4.7.1, isolated HOME/save directories. Completed 170 instances in 200.0s,
exit 0, strict runtime log guard passed. Source start/end fingerprints match.
No code/test edits overlapped the run. Programmatic checks verified all 170
seed/arena/roster configurations match the preceding damage-ledger baseline.

| Metric | Baseline eaf22 | Candidate a85fb |
| --- | --- | --- |
| Expert point share | 0.4125 | 0.4964412811 |
| Seat wins | 41 / 20 / 28 / 23 | 31 / 21 / 37 / 23 |
| Slot bias | 0.1160714286 | 0.0803571429 |
| Average baseline duration | 17.3355655s | 27.0994048s |
| Expert first eliminated, difficulty rows only | 50 / 56 | 39 / 56 |
| Near-stationary Expert victim hits, difficulty rows only | 355 / 446 | 155 / 431 |
| Expert warning | yes | yes |
| Spawn-slot warning | yes | no in this sample |

Point share is the existing balance metric, not win rate. Near-stationary uses
planar speed below 0.5 at the damage callback. The 56 difficulty comparisons are
free-for-all, not two teams. Baseline duration uses the 112 baseline instances.

The candidate reduced stationary exposure and improved this sample, but remained
below the unchanged 0.52 Expert threshold and lengthened average rounds. This is
insufficient for acceptance; no independent seed validation or full-suite claim
is made for this rejected version. Do not lower the threshold or substitute a
passing map for the failed oasis sample. A future candidate should distinguish
temporary repositioning from sustained retreat and still pass independent seeds.

## Restoration and evidence

Removed only this turn's seven production lines and 28 fixture lines. Both files
were checked byte-for-byte against HEAD before re-syncing the test runtime.
The working tree returned clean and the runtime fingerprint returned to:
`eaf22be8a2e1fc92eec956478b1156c864d7c6afc1be68493036ecec8a4bd65e`.
Restored original stationary-aim suite: 65 assertions, exit 0, strict test guard
passed. The prior full 427688-assertion qualification was not rerun this turn.

Sibling `qualification-damaged-spacing-rejected-2026-10-15/` preserves candidate
source/test copies, red/green/restored logs, synthetic trace and reports only.
The rejected candidate files are evidence, not active release source.

- Report SHA-256: `b841c5f9bb138a602770c7c7443ea3abe3890b905257113bf7a94358c2908979`
- Trace SHA-256: `9aecafad773f1f10c835ed109861952a1a45843d798ce31a71377da233b86929`
- Natural log SHA-256: `18ceede19b8432145e45e144ec2d2dd5074cb9f9451695358a8886583ac7c6f1`

Tank balance, physical-device and production qualification remain open. No push,
merge, Railway mutation, fresh native Archive, upload or Apple submission occurred.
