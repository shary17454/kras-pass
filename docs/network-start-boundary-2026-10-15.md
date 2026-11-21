# Online match-start boundary - 2026-10-15

Status: client correction verified locally; Stage 0 QA_PENDING / MERGE_PENDING.
This does not qualify production online gameplay or an App Store release.

## Reproduced defect

Net accepted malformed `start` messages and installed their epoch/config/roster,
cleared pending result/input state and emitted a scene-start request before any
roster validation. Eight synthetic invalid messages produced 40 failed assertions
and 1 passed assertion on unchanged production code, with exit 1 and no fixture
parse error. Cases included duplicate real IDs, duplicate/reordered slots,
out-of-range characters, fractional rules, unknown games and mismatched arenas.

## Correction

`src/net/net_service.gd` now checks the complete fields used to construct an
online MatchConfig before mutating match state:

- Finite integral epoch and seed within the server's numeric contract.
- Two to four canonical ordered slots, bounded character indexes and names.
- Unique real peer IDs; repeated ID zero remains permitted for server Bots.
- The local peer must actually belong to the assigned match.
- Known online game/arena pair, valid rounds/difficulty and optional race laps.
- Optional sudden-death contender list must have unique valid slot indexes.

Malformed starts emit the existing generic online error without replacing the
current epoch, match data, input state or pending result. Older valid start
epochs are ignored while an existing match is installed. Accepted messages are
still deep-copied and converted through the existing MatchConfig path.
No authority, protocol version, endpoint, server, scoring or gameplay rule changed.

This is specifically the start-message boundary. It is not complete validation
of welcome, room listings, room views, full tournament metadata or every other
control-plane message. Those paths remain separate review items; no blanket
security or reconnect-completeness claim is made.

## Tests

New `tests/suites/test_network_start_boundary.gd` is registered in the standard
runner. It verifies rejection without partial state changes; malformed types,
nonfinite/fractional values, absent local identity and invalid contenders;
acceptance of current online game/arena definitions with 2-4 player slots and
Bots; JSON numeric decoding; valid MatchConfig delivery; deep-copy isolation;
and stale-epoch replay protection.

- Initial reproducer: 1 passed / 40 failed.
- Initial corrected reproducer: 41 assertions passed.
- Expanded boundary suite: 461 assertions passed.
- Existing network suite: 420 assertions passed.
- Compilation: 464 scripts, exit 0.
- Complete suite: 426000 assertions, exit 0, 224.4 seconds.
- Strict log guards passed for each positive run.

The full log's four `ERROR:` lines were inspected: one deliberate failed-write
injection in test_save.gd and three deliberate screen-load failures in
test_router_recovery.gd. They are not clean-production-run evidence. There were
no script errors or failed assertions. No source edits overlapped these runs.

Runtime source fingerprint before and after the complete suite:
`a8ccbfb50652f7b958521500549e2b1ceca61d00532e17dad907108619413fa2`.

## Evidence and limits

Sibling `../qualification-network-start-2026-10-15/` retains the baseline,
corrected, expanded, existing-network, compilation and full-suite engine logs.
No private player saves or credentials were copied.

SHA-256:

- Full suite log: `3f660fe6979bb0bf74e74dd25ddfc2c49a1afad4ee136ba438994234d5f9515a`
- net_service.gd: `57eceec72d94a140a129a75883b24aaf4a49455e65debe8fa5a16b40afae5d95`
- New suite: `c681ae87f083c876a52e329ce2b4e9eb6269021fc201c2dc9d0f784994009a10`
- Runner: `abe220b594ec32d58cfd765219227810ca7aee238c14487c709ef72b44585a9b`

The checks use local in-process services and controlled packets, not a fresh
four-process WebSocket campaign or a physical iPhone/Railway connection. Existing
server/network smoke infrastructure can provide that next layer after dependency
and source verification. AI balance, all-game playability, device energy/thermal
QA and production backup/restore/rollout gates remain open. No main merge, push,
Railway mutation, signed Xcode Archive, upload or Apple review submission occurred.
