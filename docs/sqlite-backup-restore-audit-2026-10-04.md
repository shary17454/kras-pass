# SQLite Backup Restore Audit

Auditor source: `452a513786c8204b77827f60f1af077e22d5b5a4`.
Production repository/branch: `shary17454/kras-pass`, `main`.
Deployment inspected: `79d21f7c-65f3-4ca8-a322-85d1f38c3692`, `SUCCESS`, exact
production commit `f29824f82d6f34d6d5e4b090befa17e792be6f94`.

## Method

`server/backup-audit.js` opens the existing absolute source filename read-only,
holds a read transaction and copies it using Node's `sqlite.backup` API, not a
raw main-file copy that could omit the WAL. It opens the copy as a separate
read-only database and checks integrity, foreign keys, account tables, schema
and account/session/challenge/owner contents. Content comparison uses internal
hashes of ordered rows; rows and hashes are never included in its report.

Reference: [Node SQLite backup documentation](https://nodejs.org/api/sqlite.html#sqlitebackupsourceDb-path-options).

The destination is a unique temporary directory created by `mkdtempSync`.
Both database connections are closed and the tool-owned directory is removed
in nested `finally` blocks, including failure paths. It never replaces the
live database, promotes the copy to production or reads application secrets.
No source database file is created if the requested source does not exist.

The production audit transported this exact module as a data-URL to the existing
Railway SSH command, then invoked `auditBackup(process.env.ACCOUNT_DB_PATH)`.
Only result metadata was printed; no database copy was downloaded to the Mac.
The command completed successfully, so its cleanup finished before returning.

## Results

`/tmp/kras-production-backup-restore-audit.log`:

```json
{"ok":true,"integrity":"ok","foreign_key_errors":0,"schema_matches":true,"account_schema":true,"content_matches":true,"user_version":0,"pages":9,"backup_bytes":36864}
```

`/tmp/kras-backup-audit-production-state.json` identifies the deployment above.
The production `/health` request after the audit returned `ok=true`,
`authentication_ready=true`, `multiplayer_enabled=false`.

Four automated tests passed:

- Uncheckpointed account WAL is included; main/WAL bytes, sessions, owner
  entitlement and challenge remain unchanged in the live fixture.
- Missing, relative and corrupt sources are rejected without creating a database.
- Foreign-key damage and unrelated SQLite schemas are rejected.
- A consistent snapshot compares successfully while another connection continues
  writing; original and newly created live sessions remain valid.

Full server run with all six actual Godot fixtures passed 183 tests, zero failed,
zero skipped. Log: `/tmp/kras-backup-audit-full-server.log`.

Recheck locally, using a disposable account fixture or a specifically authorized
source file:

```sh
cd server
node --test backup-audit.test.js
node --input-type=module -e 'import {auditBackup} from "./backup-audit.js"; console.log(await auditBackup(process.env.ACCOUNT_DB_PATH));'
```

## Limits And Remaining Work

This is an online backup/restore rehearsal of the current database snapshot.
It is not a durable backup: the temporary copy is deliberately deleted.
Off-host encrypted storage, retention, scheduled backup execution, restore
promotion/runbook, recovery-time/recovery-point targets and disaster recovery
remain unimplemented or unqualified. Database `user_version=0` is unchanged;
this is not a versioned account-schema migration.

No automatic backup schedule, Railway variables, production code deployment,
certificate, App Store archive, upload or review submission was changed by this
audit. All other product and release acceptance gates remain open.
