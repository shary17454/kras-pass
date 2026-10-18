import test from 'node:test';
import assert from 'node:assert/strict';
import {createCipheriv, randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {Accounts} from './accounts.js';
import {withVerifiedBackup} from './backup-audit.js';
import {createEncryptedBackup, verifyEncryptedBackup} from './encrypted-backup.js';

async function fixture(run) {
  const directory = mkdtempSync(join(tmpdir(), 'kras-encrypted-test-'));
  const source = join(directory, 'accounts.sqlite');
  const store = new Accounts(source, 'owner@example.test', () => 100);
  const key = randomBytes(32);
  try { await run({directory, source, store, key, output: join(directory, 'snapshot.krasdb')}); }
  finally { key.fill(0); store.close(); rmSync(directory, {recursive: true, force: true}); }
}

test('encrypted durable snapshot includes WAL, restores and never mutates live sessions', async () => {
  await fixture(async ({source, output, key, store, directory}) => {
    store.db.exec('PRAGMA wal_autocheckpoint=0');
    const owner = store.exchange(store.challenge().id, {subject: 'synthetic-owner', email: 'owner@example.test'});
    const before = readFileSync(source), wal = readFileSync(source + '-wal');
    const created = await createEncryptedBackup(source, output, key);
    assert.equal(created.encrypted, true);
    assert.equal(created.verification.content_matches, true);
    const ciphertext = readFileSync(output);
    assert.equal(ciphertext.subarray(0, 8).toString(), 'KRASDB01');
    assert.equal(ciphertext.includes(Buffer.from('SQLite format 3')), false);
    assert.equal(ciphertext.includes(Buffer.from('synthetic-owner')), false);
    assert.equal(statSync(output).mode & 0o777, 0o600);
    const restored = await verifyEncryptedBackup(output, key);
    assert.equal(restored.verification.integrity, 'ok');
    assert.equal(restored.verification.account_schema, true);
    assert.equal(restored.verification.foreign_key_errors, 0);
    assert.deepEqual(readFileSync(source), before);
    assert.deepEqual(readFileSync(source + '-wal'), wal);
    assert.equal(store.access(owner.token).all_games, true);
    assert.equal(readdirSync(directory).some(name => name.startsWith('.kras-encrypted-')), false);
    const printed = JSON.stringify({created, restored});
    for (const secret of [key.toString('hex'), owner.token, 'owner@example.test', 'synthetic-owner']) {
      assert.equal(printed.includes(secret), false);
    }
  });
});

test('wrong key, nonce, tag, ciphertext, magic and truncation fail closed', async () => {
  await fixture(async ({source, output, key, directory}) => {
    await createEncryptedBackup(source, output, key);
    const bytes = readFileSync(output);
    await assert.rejects(verifyEncryptedBackup(output, randomBytes(32)), /authentication_failed/);
    const damaged = join(directory, 'damaged.krasdb');
    for (const offset of [0, 8, 20, 36, bytes.length - 1]) {
      const changed = Buffer.from(bytes);
      changed[offset] ^= 1;
      writeFileSync(damaged, changed);
      await assert.rejects(verifyEncryptedBackup(damaged, key), /invalid_backup_format|authentication_failed/);
    }
    writeFileSync(damaged, bytes.subarray(0, 36));
    await assert.rejects(verifyEncryptedBackup(damaged, key), /invalid_backup_format/);
  });
});

test('never overwrites an existing backup or source, and fresh snapshots use fresh nonces', async () => {
  await fixture(async ({source, output, key, directory}) => {
    await createEncryptedBackup(source, output, key);
    const existing = readFileSync(output), before = readFileSync(source);
    await assert.rejects(createEncryptedBackup(source, output, key), /EEXIST/);
    await assert.rejects(createEncryptedBackup(source, source, key), /EEXIST/);
    assert.deepEqual(readFileSync(output), existing);
    assert.deepEqual(readFileSync(source), before);
    const second = join(directory, 'second.krasdb');
    await createEncryptedBackup(source, second, key);
    assert.notDeepEqual(readFileSync(second).subarray(8, 20), existing.subarray(8, 20));
    assert.equal(readdirSync(directory).some(name => name.startsWith('.kras-encrypted-')), false);
  });
});

test('invalid keys and destination paths do not publish artifacts', async () => {
  await fixture(async ({source, output, key}) => {
    for (const invalid of [undefined, 'secret', Buffer.alloc(31), Buffer.alloc(33)]) {
      await assert.rejects(createEncryptedBackup(source, output, invalid), /invalid_backup_key/);
      await assert.rejects(verifyEncryptedBackup(output, invalid), /invalid_backup_key/);
    }
    await assert.rejects(createEncryptedBackup(source, 'relative.krasdb', key), /invalid_backup_destination/);
    assert.equal(existsSync(output), false);
  });
});

test('verified-snapshot consumer failures still remove the plaintext temporary snapshot', async () => {
  await fixture(async ({source}) => {
    let snapshot;
    await assert.rejects(withVerifiedBackup(source, async filename => {
      snapshot = filename;
      assert.equal(existsSync(filename), true);
      throw new Error('consumer_failure');
    }), /consumer_failure/);
    assert.equal(existsSync(snapshot), false);
    await assert.rejects(withVerifiedBackup(source, null), /invalid_backup_consumer/);
  });
});

test('operator CLI creates and rehearses only explicitly named fixtures without printing keys', async () => {
  await fixture(async ({source, output, key}) => {
    const cli = fileURLToPath(new URL('./encrypted-backup-cli.js', import.meta.url));
    const env = {...process.env, KRAS_ACCOUNT_BACKUP_KEY_HEX: key.toString('hex')};
    for (const args of [['create', source, output], ['verify', output]]) {
      const result = spawnSync(process.execPath, [cli, ...args], {env, encoding: 'utf8'});
      assert.equal(result.status, 0, result.stderr);
      assert.equal(JSON.parse(result.stdout).ok, true);
      assert.equal((result.stdout + result.stderr).includes(env.KRAS_ACCOUNT_BACKUP_KEY_HEX), false);
    }
    const invalid = spawnSync(process.execPath, [cli, 'create', source, output], {
      env: {...env, KRAS_ACCOUNT_BACKUP_KEY_HEX: 'secret-that-must-not-be-printed'}, encoding: 'utf8'});
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /invalid_backup_key/);
    assert.equal(invalid.stderr.includes('secret-that-must-not-be-printed'), false);
  });
});

test('authenticated ciphertext is still rejected when the restored database is invalid', async () => {
  await fixture(async ({output, key}) => {
    const magic = Buffer.from('KRASDB01'), nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', key, nonce);
    cipher.setAAD(magic);
    const ciphertext = Buffer.concat([cipher.update(Buffer.from('not a SQLite database')), cipher.final()]);
    writeFileSync(output, Buffer.concat([magic, nonce, cipher.getAuthTag(), ciphertext]));
    await assert.rejects(verifyEncryptedBackup(output, key));
  });
});
