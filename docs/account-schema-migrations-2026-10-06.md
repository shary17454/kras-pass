# Account Schema Versioning

## Identified Gap And Changes

The existing account constructor creates four tables but leaves user_version=0.
It neither distinguishes future database formats nor supplies a transactional
upgrade path. This branch adds startup migrations without changing account
identity, token hashing, owner binding, deletion or authentication rules.

- Version 0: accept an empty database or the complete known legacy table schema.
- Version 1: record the existing tables without rewriting account rows.
- Version 2: add indexes on sessions.expires and challenges.expires for pruning.
- Reopening validates the current schema and indexes without rerunning upgrades.
- Future, negative, partial, incompatible or foreign-key-damaged schemas fail
  closed instead of resetting the database or silently downgrading it.

All migration statements and user_version updates use one BEGIN IMMEDIATE
transaction. Failure rolls back DDL and version changes. The constructor closes
its database handle if initialization fails. WAL is enabled only after schema
acceptance. The schema comparison is deliberately conservative: equivalent but
manually altered table/index definitions are not automatically adopted.

## Tests

New disposable-file migration tests cover new databases, version 0 to 2, version
1 to 2, persisted owner/session/challenge data, idempotent reopening, indexed
expiration query plans, future/negative versions, partial tables, foreign-key
damage, incompatible columns/indexes and DDL rollback. No production account
rows or secrets are exported by these tests.

The initial regression run demonstrated missing migrations. One FK-corruption
fixture initially failed during setup because Node SQLite enables foreign keys
by default; the fixture now explicitly disables enforcement only to construct
the damaged disposable source. No production enforcement was weakened.

The first full server run hit sandbox EPERM on a loopback listener; the same
tests passed with local system permission. Without Godot captures that run had
197 passes and six explicit skips. Supplying all six actual captures from the
existing d1a5a31 engine regression then produced 203 passes, zero failures and
zero skips. The final run after adding the negative-version test passed all
204 tests, with zero failures and zero skips. git diff --check also passed.

Evidence: /tmp/kras-account-migrations-server.stdout and
/tmp/kras-account-migrations-server-captures.stdout and
/tmp/kras-account-migrations-final-server.stdout. These tests use local
fixtures and loopback transport, not Railway production migration or Internet
multiplayer acceptance.

## Deployment And Rollback Gates

No production migration or deployment has occurred on this branch. Before
deploying, verify the production database's known table definitions and version,
authorize and verify a durable backup, validate restoration in an isolated
location, then coordinate the approved server release. Do not reset a rejected
database to force startup. Its existing files must be preserved for diagnosis.

An old server using these same tables ignores user_version and the additional
indexes, but rollback compatibility must still be checked against the actual
chosen server commit before deployment. This change does not provide durable
scheduled backups, retention or a complete disaster-recovery solution.

The immutable all-game natural balance campaign remains on d1a5a31. This branch
does not change minigame code, Apple signing, App Store metadata, main or Railway.
