import {backup, DatabaseSync} from 'node:sqlite';
import {createHash} from 'node:crypto';
import {mkdtempSync, rmSync, statSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {isAbsolute, join} from 'node:path';

const schemaSQL = `SELECT type, name, tbl_name, sql FROM sqlite_schema
  WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name`;
const requiredTables = ['accounts', 'challenges', 'owner_binding', 'sessions'];
const tableOrders = ['subject', 'id', 'slot', 'hash'];

function contents(database) {
  return requiredTables.map((table, i) => {
    const hash = createHash('sha256');
    for (const row of database.prepare(`SELECT * FROM ${table} ORDER BY ${tableOrders[i]}`).iterate()) {
      hash.update(JSON.stringify(row) + '\n');
    }
    return hash.digest('hex');
  });
}

// A restore rehearsal only: the live file is never replaced or opened for writes.
export async function auditBackup(sourcePath) {
  return withVerifiedBackup(sourcePath, (_filename, result) => result);
}

// The consumer must finish before the private plaintext snapshot is removed.
export async function withVerifiedBackup(sourcePath, consume) {
  if (typeof consume !== 'function') throw new Error('invalid_backup_consumer');
  if (typeof sourcePath !== 'string' || !isAbsolute(sourcePath) || !statSync(sourcePath).isFile()) {
    throw new Error('invalid_database_path');
  }
  const directory = mkdtempSync(join(tmpdir(), 'kras-backup-audit-'));
  let source, restored;
  try {
    source = new DatabaseSync(sourcePath, {readOnly: true});
    source.exec('BEGIN');
    const originalSchema = JSON.stringify(source.prepare(schemaSQL).all());
    const sourceContents = contents(source);
    const filename = join(directory, 'restore.sqlite');
    const pages = await backup(source, filename);
    restored = new DatabaseSync(filename, {readOnly: true});
    const integrity = restored.prepare('PRAGMA quick_check').all();
    const foreignKeyErrors = restored.prepare('PRAGMA foreign_key_check').all().length;
    const schemaMatches = JSON.stringify(restored.prepare(schemaSQL).all()) === originalSchema
      && JSON.stringify(source.prepare(schemaSQL).all()) === originalSchema;
    const tables = restored.prepare("SELECT name FROM sqlite_schema WHERE type='table'").all();
    const accountSchema = requiredTables.every(name => tables.some(row => row.name === name));
    const contentMatches = accountSchema && JSON.stringify(contents(restored)) === JSON.stringify(sourceContents);
    if (integrity.length !== 1 || integrity[0].quick_check !== 'ok'
      || foreignKeyErrors !== 0 || !schemaMatches || !accountSchema || !contentMatches) {
      throw new Error('backup_verification_failed');
    }
    const result = {ok: true, integrity: 'ok', foreign_key_errors: 0, schema_matches: true,
      account_schema: true, content_matches: true,
      user_version: restored.prepare('PRAGMA user_version').get().user_version,
      pages, backup_bytes: statSync(filename).size};
    return await consume(filename, result);
  } finally {
    try { restored?.close(); }
    finally {
      try { source?.close(); }
      finally { rmSync(directory, {recursive: true, force: true}); }
    }
  }
}
