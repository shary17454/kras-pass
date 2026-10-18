# Recovery-spacing candidate: improved metric, unresolved warning

Disposition: REJECTED_BALANCE_CANDIDATE. Parent code remains
`1c1626ef35e71ee8988bc8facfc0020923c5fdec`, feature/kras-online-random-rotation.
No production gameplay or permanent test change is retained from this experiment.

## Hypothesis and controlled check

The candidate made Duel AI back away from an observed rival within 3.2 units
while its own attack cooldown remained active, excluding an active swing.
Existing edge escape and delayed perception were retained. It changed neither
character stats nor player physics or acceptance thresholds.

Proposed behavior fixture: four difficulty levels, recovering/ready/swinging/
distant/hidden/edge cases, actual four-frame Fighter integration for planar
separation. Initial Y=4 isolates horizontal movement above the terrain; this
is not a standing-ground approach or full-match proof. Before: 25 passed,
eight failed. Candidate: 33 passed, strict test log guard passed. Candidate
compile: 467 scripts, exit 0. The fixture expresses the experimental tactic,
not a previously required contract; it was withdrawn with that tactic.

## Natural matched result

Godot 4.7.1, isolated HOME/save roots, --headless --fixed-fps 60,
tests/balance_contact_trace.tscn --runs=112 --only=duel_pit
--seed-offset=101000000. Natural default-pit rounds, four AI, pair-balanced
rosters, unchanged 110-second authored window.

112 baseline, 56 mirrored difficulty and two mutator/chaos instances completed:
170 records, all completed, terminal exit 0, 428.1s host time. Strict runtime
guard passed. All baseline seeds/full rosters and all difficulty seed/character/
expert-seat assignments match the prior current-source reference exactly.
No source/test edits overlapped the natural campaign. This is not independent
held-out evidence or a phone performance measurement.

| Metric | Reference | Candidate |
| --- | ---: | ---: |
| Character bias | 0.1607143 | 0.0982143 |
| Seat bias | 0.0535714 | 0.0446429 |
| Sakhra credited wins / 112 | 32 | 25 |
| Mean natural duration | 63.9491s | 68.7299s |
| Expert placement-point share | 0.6543002 | 0.6592466 |
| Expert outright wins / 56 | 55 | 52 |
| Easy outright wins / 56 | 1 | 4 |
| Baseline ties | 0 | 0 |
| Flags | character advantage | character advantage |

Candidate character wins: Barq9, Fanoos15, Ghaim9, Mowja12, Nabta11, Ramla14,
Sakhra25, Turs17. Seat wins: [33,25,27,27]. Both smoke cases completed.

The observed improvement is retained as evidence, not dismissed as no effect.
However, the previously declared condition required clearing the warning before
independent acceptance. It did not clear. No threshold was loosened, unfavorable
report removed or independent sample pooled into this matched comparison.
The announced 105000000 held-out acceptance run was therefore NOT launched.

## Restoration and evidence

Only our uncommitted candidate block, runner registration and experimental test
were removed with scoped patches. The accepted parent initialization fix and
all its existing tests remain. No user work or shared Git history was reverted.
The 1006 tracked source/scenes/data/tools/tests/project files were byte-compared
against the preserved Git extraction at parent 1c1626e: no mismatches and no
extra .gd/.tscn/.json test files. Checkout Git status was clean before docs.

Fresh restored compile: 466 scripts. Fresh restored AI visibility/initialization
suite: 4524 assertions. Both strict guards passed. No new full-suite run is
claimed; the previous 428109-assertion full run belongs to the exact restored
code/test source verified above. No new network/device or rendered campaign.

Source fingerprints:
- Reference/restored: `cb22e0abe5d98a8cd2fe0d1ab315181712ace70b12bd5de0164bf60cdbc43a79`
- Candidate, stable at both campaign endpoints: `4ec6083c6c2f61d35019deb72315eba1746ed04d434c88f5921a98a4c773ef55`

Selected-source fingerprints exclude tests and many assets, not native archive
attestation. Separate restoration comparison covers tracked tests as well.
Candidate report SHA-256:
`857d6214b4cf0b5d4ec437ad25dded8abe71bafd9e00196cd616875b24861838`.
Candidate engine log SHA-256:
`dbfb460bedf41c784158421dcad5409ed5dc55592c0620e24b1cacb0fd7a8858`.

Sibling qualification-duellist-spacing-rejected-2026-10-15/ preserves candidate
source/fixture/runner overlays, red/green/compile, both reports/HTML/traces/logs,
matched-comparison.json, restoration-attestation.json and restored verification
logs. Only synthetic artifacts were copied, not private player saves.

Next: isolate attack-versus-ram exposure and character matchups before another
intervention; do not present this tactic alone as balanced. Stage 0 remains
QA_PENDING/MERGE_PENDING. No READY promotion, main push, Railway deployment,
native archive, upload or Apple review submission. Physical-device and
production backup/restore gates remain unresolved.
