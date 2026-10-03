# Durable adventure reward qualification

Implementation: `77ac734d868299cf100cb9a9c79466f75254171f`.
Branch: `fix/kras-adventure-durable-rewards`, based on PR #26.

## Corrected behavior

Adventure previously remembered rewards only in a result object's metadata.
Reconstructing the object could pay again, and changing the active profile
could attribute a pending outcome to another player. The initial targeted
regression run reproduced four failures (105 passed, four failed).

Round results now export a random persistence identity. Aggregates derive
their identity from the ordered round identities, so reconstructing the same
completed rounds does not create a new payment event. This identity is not an
input to physics, scoring, the seeded RNG, or the network score protocol.

Adventure receipts are stored per local profile, keyed by result identity and
bound to the world/stage. Receipt, gems, first-clear trophy, progression and
achievement changes share the existing atomic profile write through a save
batch. Displayed rewards are normalized from JSON numbers to the original
integer contract and returned as copies. A real new match remains eligible
for ordinary rewards but not another first-clear bonus.

The session captures its local owner and sets that identity in the human
player configuration. A profile switch cannot silently redirect its reward.
Existing profiles without the optional receipt branch remain supported by
schema 2; no progress is reset. Legacy in-memory reward metadata can be adopted
without granting the reward again. An old result that never had an identity
or cached reward cannot be retrospectively identified as an already-paid event.

The adventure rematch button previously dropped its completion callback. It
now reconstructs a validated stage session and preserves the complete match
configuration through a resource copy, retaining modifiers, duration and
players. Missing world/stage, wrong game or wrong owner goes back to the map
instead of starting an untracked adventure match.

## Executed evidence

- Adventure/party: 133 assertions passed, including JSON cache reconstruction,
  actual profile-slot and result-resource disk round trips, fresh-match rewards,
  profile isolation, aggregate identity stability and valid rematch sessions.
- The first-clear fixture observed exactly one `profile_saved` event. Its disk
  document contained the receipt, increased gem count and first-clear trophy.
- Save/progression: 100 assertions passed, including existing migration and
  corruption-recovery checks.
- Scoring: 47 assertions passed after the final aggregate identity change.
- Lifecycle: 13 assertions passed after the final change.
- Replay: 71 assertions passed, including recorded-match and chaos playback.
- Compilation: all 324 scripts compiled after the final changes.
- All 379 selected tracked Godot/data input files matched the owned warm
  runtime byte-for-byte. This is not a clean release archive provenance claim.
- Relevant completed-run log guards and whitespace checks passed. The macOS
  sandbox CA lookup diagnostic is not proof of production TLS behavior.

During development, the restart fixture caught JSON float-versus-int reward
differences; reward normalization fixed them. One save invocation selected the
nonexistent filter `save_system` and correctly failed with zero selected suites;
it is not counted as a pass. It was corrected to the actual `save` suite.

## Limits and remaining release gates

Receipts are not evicted, so old current-format results cannot become payable
again merely because many newer matches were played. Large lifetime profile
size and write latency still require a dedicated performance budget; this
focused fixture does not certify battery, temperature or long-session FPS.
The save protocol remains corruption recovery, not protection against users
editing their own local files. Hardware power interruption was not reproduced.

The rematch session and routing code are covered by source and focused tests,
not a physical iPhone touch/UI run. No certificate import, new certificate,
archive, upload, previous-review withdrawal or App Store review submission was
performed. Main/Railway do not yet contain this feature branch.

Full current-source CI, the remaining balance findings, production online
qualification, physical-device QA, current App Store version/build checks and
a verified signed release archive remain required before submission.
