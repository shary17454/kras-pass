# Encrypted account backup and restore rehearsal

Implemented operator-only modules, not an automatic production operation:
server/encrypted-backup.js and server/encrypted-backup-cli.js.
The existing backup-audit API retains its result contract and now shares its
verified read-only WAL snapshot through withVerifiedBackup. The callback is
awaited before the private plaintext temporary snapshot is removed.

Creation verifies account schema, ordered account/session/challenge/owner
contents, quick_check and foreign keys against the held source snapshot.
It then encrypts the snapshot with AES-256-GCM and a fresh random 96-bit nonce.
The format has an authenticated KRASDB01 magic, nonce, tag and ciphertext.
The key is external and never embedded in the artifact or result metadata.
Encryption is not a substitute for access control, key custody or off-host
storage. Keep each backup associated with its key version in the operator's
protected inventory; key rotation does not recover backups whose keys are lost.

Publication writes a mode-0600 encrypted temporary file, fsyncs it, publishes
by a no-overwrite hard link on the same filesystem and fsyncs the parent.
No existing backup or database is replaced. The tool removes its own temporary
directory, not other backups. Plaintext buffers are cleared after use; private
temporary restore files are removed in finally blocks. JavaScript/runtime
copies and external filesystem snapshots are not claimed securely erased.

Verification authenticates ciphertext before using a private restored SQLite
file and reruns the account/schema/integrity rehearsal. It never promotes a
restored database over production. Input size is bounded to 256 MiB plus the
36-byte envelope; oversized backups require an explicitly designed streaming
implementation rather than truncation or unbounded allocation.

## Operator commands

Use Node 24 or later. Inject KRAS_ACCOUNT_BACKUP_KEY_HEX from a trusted secret
manager into only the command's environment (64 hex characters representing
a cryptographically random 32-byte key). Never put the key on the command
line, in Git, logs or a chat. Key custody is separate from Apple signing.

```sh
node server/encrypted-backup-cli.js create /absolute/authorized/accounts.sqlite /absolute/private/backup.krasdb
node server/encrypted-backup-cli.js verify /absolute/private/backup.krasdb
```

Commands above are instructions, not evidence of a production run. Source,
destination directory, secret access and production execution need explicit
approval. CLI prints only verification metadata and redacts native error
paths by printing filesystem error codes. Missing/wrong keys fail closed.

Before a production migration: obtain approval, create and verify the named
encrypted snapshot, transfer to approved off-host storage without the key,
verify the retained copy, record restore key version and source deployment,
then follow a reviewed maintenance/restore-promotion plan. Do not overwrite
the live database using this rehearsal tool. Scheduling, off-host retention,
failure alerts and actual disaster-recovery RPO/RTO are still unqualified.

## Actual tests and limits

All 251 server tests pass locally, zero failures/skips, with six fresh Godot
world captures from the preceding 392787-assertion regression. Before local
permission, the old 244-test run had one EPERM listen failure on 127.0.0.1;
the authorized local retry passed all 244. That environment failure was not
hidden by a larger timeout or weakened test. npm audit reports zero known
vulnerabilities; dependency versions were not changed.

Seven added tests cover WAL snapshot preservation, actual encrypted restore,
wrong key and modified magic/nonce/tag/ciphertext/truncation, immutable existing
output/source, independent nonces, malformed key/path, consumer failure
cleanup, CLI create/verify/key non-disclosure and authenticated non-SQLite
rejection. Existing four backup-audit tests still pass. Data is synthetic.

Raw logs retained in ../qualification-encrypted-backup-2026-10-08/.
No production database, secret store, Railway variable, scheduled job or
deployment was accessed or modified. No App Store archive, upload or review
submission was performed. Production execution remains an approval gate.
The ongoing network campaign 37834212081 tests the earlier pinned 47d3347
checkout, not these later backup modules; do not relabel its source.
