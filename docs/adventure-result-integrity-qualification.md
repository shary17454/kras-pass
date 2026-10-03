# Adventure Result Integrity

Base: main `5da88fbd664ca5987c7abcf649e1e5db21e4a6c9`.

## Defects and Changes

The previous adventure callback awarded progress without checking `finished_naturally`, treated any shared first place as a clear, and allowed repeated callbacks to grant gems again. `stars_for(0, 4)` also treated an absent placement as a three-star win.

The production callback now delegates reward calculation to `award_result`:

- Interrupted, missing, malformed, wrong-game and invalid-placement results grant no gems, stars, trophies, achievements or progression.
- A shared first place retains completed participation/podium rewards but does not clear the stage or earn the outright-win bonus.
- An outright completed win retains three stars, clear state, first-clear reward and existing gems.
- Result-local reward receipts prevent duplicate rewards from the same result callback and retain the original result-screen amounts.
- Returned receipt copies cannot be modified by the results UI.

No save schema or existing unlocked progress was removed. Existing saves remain intact; previously incorrectly granted rewards are not retroactively revoked.

## Verification

- Final `party_progress`: 96 assertions passed, exit 0.
- Save/corruption/migration suite: 100 assertions passed, exit 0. This ran before the final additional malformed-array guard; that guard does not alter save code or schema.
- Lifecycle: 13 assertions passed, exit 0, before that same final guard.
- Final compile: 324 scripts passed, exit 0.
- Both modified source/test files byte-match the runtime fixture.
- `git diff --check` passed.

Logs: `/tmp/kras-adventure-integrity-party-final-v2.log`, `/tmp/kras-adventure-integrity-save.log`, `/tmp/kras-adventure-integrity-lifecycle.log`, `/tmp/kras-adventure-integrity-compile-final.log`.

The first implementation used a colon-delimited metadata identifier. Godot rejected that identifier and two duplicate-reward assertions failed. The final implementation uses a valid `adventure_rewards` metadata key containing a dictionary; all final assertions passed. The initial failure was not a pre-fix production baseline.

The sandboxed Mac emitted a system CA certificate lookup error during engine startup. Tests compiled and exited successfully, but these runs do not establish TLS or production authentication. Save tests deliberately simulate corrupt files and write failures; their expected diagnostic logs are not production incidents.

## Remaining Qualification

- Receipts are result-local, not durable attempt IDs. A separately reconstructed result after process restart is not protected by this change.
- Boss defeat versus deadline completion remains separate, unqualified adventure behavior.
- This focused suite tests the real save/progression services and reward method, not rendered results-screen navigation on an iPhone.
- Real-device gameplay, performance, online acceptance, complete balance review and current-source release CI remain required.
- This branch is not merged into main or deployed to Railway. No Archive, signing, App Store upload or review submission occurred.
