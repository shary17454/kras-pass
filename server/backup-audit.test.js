import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync, rmSync, readFileSync, writeFileSync, existsSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {Accounts} from './accounts.js';
import {auditBackup} from './backup-audit.js';

test('restore audit includes uncheckpointed account WAL and leaves live data unchanged', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'kras-backup-test-'));
  const filename = join(directory, 'accounts.sqlite');
  const store = new Accounts(filename, 'owner@example.test', () => 100);
  try {
    store.db.exec('PRAGMA wal_autocheckpoint=0');
    const owner = store.exchange(store.challenge().id, {subject: 'owner', email: 'owner@example.test'});
    const guest = store.exchange(store.challenge().id, {subject: 'guest'});
    const challenge = store.challenge();
    assert.ok(existsSync(filename + '-wal'));
    const beforeMain = readFileSync(filename);
    const beforeWAL = readFileSync(filename + '-wal');
    const before = store.db.prepare('SELECT * FROM sessions ORDER BY hash').all();
    const report = await auditBackup(filename);
    assert.equal(report.ok, true);
    assert.equal(report.account_schema, true, 'WAL-only schema must be included');
    assert.equal(report.integrity, 'ok');
    assert.equal(report.schema_matches, true);
    assert.equal(report.content_matches, true);
    assert.equal(report.foreign_key_errors, 0);
    assert.ok(report.pages > 0 && report.backup_bytes > 0);
    assert.deepEqual(readFileSync(filename), beforeMain);
    assert.deepEqual(readFileSync(filename + '-wal'), beforeWAL);
    assert.deepEqual(store.db.prepare('SELECT * FROM sessions ORDER BY hash').all(), before);
    assert.equal(store.access(owner.token).all_games, true);
    assert.equal(store.access(guest.token).all_games, false);
    assert.equal(store.nonce(challenge.id), challenge.nonce);
    const printed = JSON.stringify(report);
    for (const secret of [owner.token, guest.token, challenge.id, challenge.nonce, 'owner@example.test']) {
      assert.ok(!printed.includes(secret));
    }
  } finally { store.close(); rmSync(directory, {recursive: true, force: true}); }
});

test('audit refuses missing, relative and corrupt source files without creating a database', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'kras-backup-test-'));
  try {
    const missing = join(directory, 'missing.sqlite');
    await assert.rejects(auditBackup(missing));
    assert.equal(existsSync(missing), false);
    await assert.rejects(auditBackup('accounts.sqlite'), /invalid_database_path/);
    await assert.rejects(auditBackup(directory), /invalid_database_path/);
    const corrupt = join(directory, 'corrupt.sqlite');
    writeFileSync(corrupt, 'not sqlite');
    await assert.rejects(auditBackup(corrupt));
    assert.equal(readFileSync(corrupt, 'utf8'), 'not sqlite');
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('audit rejects foreign-key damage and unrelated SQLite schemas', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'kras-backup-test-'));
  const filename = join(directory, 'accounts.sqlite');
  const store = new Accounts(filename, 'owner@example.test');
  try {
    store.db.exec("PRAGMA foreign_keys=OFF; INSERT INTO sessions VALUES('bad','missing',9999999999)");
    await assert.rejects(auditBackup(filename), /backup_verification_failed/);
    assert.equal(store.db.prepare('SELECT count(*) AS n FROM sessions').get().n, 1);
    const other = join(directory, 'other.sqlite');
    const unrelated = new DatabaseSync(other);
    unrelated.exec('CREATE TABLE other(id INTEGER)');
    unrelated.close();
    await assert.rejects(auditBackup(other));
  } finally { store.close(); rmSync(directory, {recursive: true, force: true}); }
});

test('audit compares one WAL snapshot while the service continues writing', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'kras-backup-test-'));
  const filename = join(directory, 'accounts.sqlite');
  const store = new Accounts(filename, 'owner@example.test', () => 100);
  try {
    const original = store.exchange(store.challenge().id, {subject: 'original'});
    const audit = auditBackup(filename);
    const added = store.exchange(store.challenge().id, {subject: 'added'});
    const report = await audit;
    assert.equal(report.content_matches, true);
    assert.ok(store.access(original.token));
    assert.ok(store.access(added.token));
    assert.equal(store.db.prepare('SELECT count(*) AS n FROM accounts').get().n, 2);
  } finally { store.close(); rmSync(directory, {recursive: true, force: true}); }
});
