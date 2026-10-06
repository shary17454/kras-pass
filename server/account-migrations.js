export const ACCOUNT_SCHEMA_VERSION = 2;

const tables = {
  accounts: 'CREATE TABLE accounts(subject TEXT PRIMARY KEY, created INTEGER NOT NULL)',
  owner_binding: `CREATE TABLE owner_binding(slot INTEGER PRIMARY KEY CHECK(slot=1),
    subject TEXT NOT NULL UNIQUE REFERENCES accounts(subject))`,
  challenges: 'CREATE TABLE challenges(id TEXT PRIMARY KEY, nonce TEXT NOT NULL, expires INTEGER NOT NULL)',
  sessions: `CREATE TABLE sessions(hash TEXT PRIMARY KEY,
    subject TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, expires INTEGER NOT NULL)`,
};
const normalized = sql => sql.replace(/\s+/g, '').replace(/;$/, '').toLowerCase();
const indexes = {
  sessions_expiry: 'CREATE INDEX sessions_expiry ON sessions(expires)',
  challenges_expiry: 'CREATE INDEX challenges_expiry ON challenges(expires)',
};

function validateTables(db) {
  for (const [name, definition] of Object.entries(tables)) {
    const existing = db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name=?").get(name);
    if (!existing || normalized(existing.sql) !== normalized(definition)) {
      throw new Error(`Unsupported account schema: ${name}`);
    }
  }
  if (db.prepare('PRAGMA foreign_key_check').all().length) {
    throw new Error('Account schema contains foreign-key violations');
  }
}

export function migrateAccounts(db) {
  db.exec('BEGIN IMMEDIATE');
  try {
    let version = db.prepare('PRAGMA user_version').get().user_version;
    if (version < 0) throw new Error('Unsupported negative account schema version');
    if (version > ACCOUNT_SCHEMA_VERSION) {
      throw new Error('Account database schema is newer than this server supports');
    }
    if (version === 0) {
      // Only an empty database or the complete known legacy schema is adopted.
      const existing = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all();
      if (existing.length === 0) {
        for (const definition of Object.values(tables)) db.exec(definition);
      }
      validateTables(db);
      db.exec('PRAGMA user_version=1');
      version = 1;
    } else {
      validateTables(db);
    }
    if (version === 1) {
      db.exec(`
        CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires);
        CREATE INDEX IF NOT EXISTS challenges_expiry ON challenges(expires);
        PRAGMA user_version=2;
      `);
    }
    for (const [name, definition] of Object.entries(indexes)) {
      const existing = db.prepare("SELECT sql FROM sqlite_master WHERE type='index' AND name=?").get(name);
      if (!existing || normalized(existing.sql) !== normalized(definition)) {
        throw new Error(`Unsupported account schema index: ${name}`);
      }
    }
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}
