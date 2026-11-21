import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Accounts, digest} from './accounts.js';

const legacy = `
  CREATE TABLE accounts(subject TEXT PRIMARY KEY, created INTEGER NOT NULL);
  CREATE TABLE owner_binding(slot INTEGER PRIMARY KEY CHECK(slot=1),
    subject TEXT NOT NULL UNIQUE REFERENCES accounts(subject));
  CREATE TABLE challenges(id TEXT PRIMARY KEY, nonce TEXT NOT NULL, expires INTEGER NOT NULL);
  CREATE TABLE sessions(hash TEXT PRIMARY KEY,
    subject TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, expires INTEGER NOT NULL);
`;
function fixture(run) {
  const directory = mkdtempSync(join(tmpdir(), 'kras-schema-test-'));
  const path = join(directory, 'accounts.sqlite');
  try { return run(path); } finally { rmSync(directory, {recursive: true, force: true}); }
}
function seed(path, version = 0) {
  const db = new DatabaseSync(path);
  try {
    db.exec(legacy);
    db.prepare('INSERT INTO accounts VALUES(?,?)').run('owner-sub', 100);
    db.prepare('INSERT INTO owner_binding VALUES(1,?)').run('owner-sub');
    db.prepare('INSERT INTO challenges VALUES(?,?,?)').run('challenge-id', 'nonce', 900);
    db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(digest('test-session'), 'owner-sub', 900);
    db.exec(`PRAGMA user_version=${version}`);
  } finally { db.close(); }
}
function snapshot(path) {
  const db = new DatabaseSync(path, {readOnly: true});
  try {
    return {
      version: db.prepare('PRAGMA user_version').get().user_version,
      schema: db.prepare("SELECT type,name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").all(),
      accounts: db.prepare('SELECT * FROM accounts ORDER BY subject').all(),
      sessions: db.prepare('SELECT * FROM sessions ORDER BY hash').all(),
    };
  } finally { db.close(); }
}

test('fresh database reaches schema 2 with expiry indexes', () => {
  const store = new Accounts(':memory:', 'owner@example.test');
  try {
    assert.equal(store.db.prepare('PRAGMA user_version').get().user_version, 2);
    const indexes = store.db.prepare("SELECT name FROM sqlite_master WHERE type='index'").all().map(row => row.name);
    assert.ok(indexes.includes('sessions_expiry'));
    assert.ok(indexes.includes('challenges_expiry'));
  } finally { store.close(); }
});

test('legacy schema migration preserves owner, sessions and challenge then reopens idempotently', () => fixture(path => {
  seed(path);
  const before = snapshot(path);
  const store = new Accounts(path, 'different@example.test', () => 200);
  try {
    assert.equal(store.db.prepare('PRAGMA user_version').get().user_version, 2);
    assert.equal(store.access('test-session').all_games, true);
    assert.equal(store.nonce('challenge-id'), 'nonce');
    assert.deepEqual(store.db.prepare('SELECT * FROM accounts ORDER BY subject').all(), before.accounts);
    assert.deepEqual(store.db.prepare('SELECT * FROM sessions ORDER BY hash').all(), before.sessions);
  } finally { store.close(); }
  const migrated = snapshot(path);
  const reopened = new Accounts(path, 'owner@example.test', () => 200);
  reopened.close();
  assert.deepEqual(snapshot(path), migrated);
}));

test('schema 1 upgrades indexes without changing stored data', () => fixture(path => {
  seed(path, 1);
  const before = snapshot(path);
  const store = new Accounts(path, 'owner@example.test', () => 200);
  try {
    assert.equal(store.db.prepare('PRAGMA user_version').get().user_version, 2);
    assert.deepEqual(store.db.prepare('SELECT * FROM sessions ORDER BY hash').all(), before.sessions);
    for (const table of ['sessions', 'challenges']) {
      const plan = store.db.prepare(`EXPLAIN QUERY PLAN DELETE FROM ${table} WHERE expires<=?`).all(200);
      assert.ok(plan.some(row => row.detail.includes(`${table}_expiry`)), `${table}: indexed expiration`);
    }
  } finally { store.close(); }
}));

test('future schema is rejected without downgrading or changing contents', () => fixture(path => {
  seed(path, 99);
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /newer|unsupported/i);
  assert.deepEqual(snapshot(path), before);
}));

test('negative schema version is rejected without rewriting the database', () => fixture(path => {
  seed(path, -1);
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /unsupported/i);
  assert.deepEqual(snapshot(path), before);
}));

test('partial legacy schema is rejected without creating missing account tables', () => fixture(path => {
  const db = new DatabaseSync(path);
  db.exec('CREATE TABLE accounts(subject TEXT PRIMARY KEY, created INTEGER NOT NULL)');
  db.close();
  assert.throws(() => new Accounts(path, 'owner@example.test'), /schema/i);
  const read = new DatabaseSync(path, {readOnly: true});
  try {
    assert.equal(read.prepare('PRAGMA user_version').get().user_version, 0);
    assert.equal(read.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table'").get().count, 1);
  } finally { read.close(); }
}));

test('foreign-key damage refuses migration and preserves diagnostic source', () => fixture(path => {
  seed(path);
  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys=OFF');
  db.exec("INSERT INTO sessions VALUES('orphan','missing',999)");
  db.close();
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /schema|foreign/i);
  assert.deepEqual(snapshot(path), before);
}));

test('migration error rolls back both version and earlier DDL', () => fixture(path => {
  seed(path);
  const db = new DatabaseSync(path);
  db.exec('CREATE TABLE challenges_expiry(value TEXT)');
  db.close();
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'));
  assert.deepEqual(snapshot(path), before);
}));

test('existing index with incompatible definition refuses migration and rolls back', () => fixture(path => {
  seed(path, 1);
  const db = new DatabaseSync(path);
  db.exec('CREATE INDEX sessions_expiry ON accounts(created)');
  db.close();
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /schema index/i);
  assert.deepEqual(snapshot(path), before);
}));

test('current version with missing index fails rather than silently accepting damaged schema', () => fixture(path => {
  seed(path, 2);
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /schema index/i);
  assert.deepEqual(snapshot(path), before);
}));

test('incompatible legacy columns fail without altering account rows or schema', () => fixture(path => {
  seed(path);
  const db = new DatabaseSync(path);
  db.exec('ALTER TABLE sessions RENAME COLUMN expires TO valid_until');
  db.close();
  const before = snapshot(path);
  assert.throws(() => new Accounts(path, 'owner@example.test'), /schema: sessions/i);
  assert.deepEqual(snapshot(path), before);
}));
