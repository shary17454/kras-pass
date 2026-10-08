import {createCipheriv, createDecipheriv, randomBytes} from 'node:crypto';
import {closeSync, fsyncSync, linkSync, mkdtempSync, openSync, readFileSync,
  rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, isAbsolute, join} from 'node:path';
import {auditBackup, withVerifiedBackup} from './backup-audit.js';

const MAGIC = Buffer.from('KRASDB01');
const MAX_BYTES = 256 * 1024 * 1024;

function requireKey(key) {
  if (!Buffer.isBuffer(key) || key.length !== 32) throw new Error('invalid_backup_key');
}

function readBounded(filename, limit = MAX_BYTES) {
  if (typeof filename !== 'string' || !isAbsolute(filename)
    || !statSync(filename).isFile() || statSync(filename).size > limit) {
    throw new Error('invalid_backup_file');
  }
  const data = readFileSync(filename);
  if (data.length > limit) throw new Error('invalid_backup_file');
  return data;
}

// Publish a complete encrypted artifact without replacing an existing backup.
function publish(filename, data) {
  if (typeof filename !== 'string' || !isAbsolute(filename)) throw new Error('invalid_backup_destination');
  const directory = mkdtempSync(join(dirname(filename), '.kras-encrypted-'));
  const temporary = join(directory, 'backup');
  try {
    writeFileSync(temporary, data, {flag: 'wx', mode: 0o600});
    const file = openSync(temporary, 'r');
    try { fsyncSync(file); } finally { closeSync(file); }
    linkSync(temporary, filename);
    const parent = openSync(dirname(filename), 'r');
    try { fsyncSync(parent); } finally { closeSync(parent); }
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}

export async function createEncryptedBackup(sourcePath, destination, key) {
  requireKey(key);
  if (typeof destination !== 'string' || !isAbsolute(destination)) throw new Error('invalid_backup_destination');
  return withVerifiedBackup(sourcePath, (snapshot, verification) => {
    const plaintext = readBounded(snapshot);
    try {
      const nonce = randomBytes(12);
      const cipher = createCipheriv('aes-256-gcm', key, nonce);
      cipher.setAAD(MAGIC);
      const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
      const envelope = Buffer.concat([MAGIC, nonce, cipher.getAuthTag(), ciphertext]);
      publish(destination, envelope);
      return {ok: true, encrypted: true, format: 1, bytes: envelope.length,
        verification};
    } finally {
      plaintext.fill(0);
    }
  });
}

// Rehearse only: never overwrite the live database or publish plaintext.
export async function verifyEncryptedBackup(filename, key) {
  requireKey(key);
  const envelope = readBounded(filename, MAX_BYTES + 36);
  if (envelope.length <= 36 || !envelope.subarray(0, 8).equals(MAGIC)) {
    throw new Error('invalid_backup_format');
  }
  let plaintext;
  try {
    const decipher = createDecipheriv('aes-256-gcm', key, envelope.subarray(8, 20));
    decipher.setAAD(MAGIC);
    decipher.setAuthTag(envelope.subarray(20, 36));
    const chunk = decipher.update(envelope.subarray(36));
    try { plaintext = Buffer.concat([chunk, decipher.final()]); }
    finally { chunk.fill(0); }
  } catch {
    throw new Error('backup_authentication_failed');
  }
  let directory;
  try {
    directory = mkdtempSync(join(tmpdir(), 'kras-encrypted-restore-'));
    const database = join(directory, 'restore.sqlite');
    writeFileSync(database, plaintext, {flag: 'wx', mode: 0o600});
    const verification = await auditBackup(database);
    return {ok: true, encrypted: true, format: 1, verification};
  } finally {
    plaintext.fill(0);
    if (directory) rmSync(directory, {recursive: true, force: true});
  }
}
