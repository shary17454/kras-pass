import {DatabaseSync} from 'node:sqlite';
import {createHash, randomBytes} from 'node:crypto';

export const digest = value => createHash('sha256').update(value).digest('hex');
const random = () => randomBytes(32).toString('base64url');

export class Accounts {
  constructor(path, ownerEmail, now = () => Math.floor(Date.now() / 1000)) {
    this.db = new DatabaseSync(path);
    this.ownerEmail = ownerEmail.trim().toLowerCase();
    this.now = now;
    this.db.exec(`
      PRAGMA journal_mode=WAL;
      PRAGMA foreign_keys=ON;
      PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS accounts(subject TEXT PRIMARY KEY, created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS owner_binding(slot INTEGER PRIMARY KEY CHECK(slot=1),
        subject TEXT NOT NULL UNIQUE REFERENCES accounts(subject));
      CREATE TABLE IF NOT EXISTS challenges(id TEXT PRIMARY KEY, nonce TEXT NOT NULL, expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY,
        subject TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, expires INTEGER NOT NULL);
    `);
  }

  challenge() {
    this.prune();
    const id = random(), nonce = random(), expires = this.now() + 300;
    this.db.prepare('INSERT INTO challenges VALUES(?,?,?)').run(id, nonce, expires);
    return {id, nonce, expires};
  }

  nonce(id) {
    return this.db.prepare('SELECT nonce FROM challenges WHERE id=? AND expires>?')
      .get(id, this.now())?.nonce;
  }

  exchange(challengeID, identity) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const challenge = this.db.prepare('DELETE FROM challenges WHERE id=? AND expires>? RETURNING id')
        .get(challengeID, this.now());
      if (!challenge) throw new Error('Challenge expired or used');
      this.db.prepare('INSERT OR IGNORE INTO accounts VALUES(?,?)').run(identity.subject, this.now());
      if (identity.email === this.ownerEmail) {
        this.db.prepare('INSERT OR IGNORE INTO owner_binding VALUES(1,?)').run(identity.subject);
      }
      const token = random(), expires = this.now() + 86400;
      this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(digest(token), identity.subject, expires);
      const access = this.access(token);
      this.db.exec('COMMIT');
      return {token, expires, ...access};
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  access(token) {
    const session = this.db.prepare('SELECT subject, expires FROM sessions WHERE hash=? AND expires>?')
      .get(digest(token), this.now());
    if (!session) return null;
    const owner = this.db.prepare('SELECT subject FROM owner_binding WHERE slot=1').get();
    return {subject: session.subject, expires: session.expires, all_games: owner?.subject === session.subject};
  }

  logout(token) {
    this.db.prepare('DELETE FROM sessions WHERE hash=?').run(digest(token));
  }

  deleteAccount(token, subject, challengeID) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      if (this.access(token)?.subject !== subject || !this.nonce(challengeID)) {
        throw new Error('Account confirmation required');
      }
      this.db.prepare('DELETE FROM challenges WHERE id=?').run(challengeID);
      this.db.prepare('DELETE FROM owner_binding WHERE subject=?').run(subject);
      this.db.prepare('DELETE FROM accounts WHERE subject=?').run(subject);
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  prune() {
    this.db.prepare('DELETE FROM challenges WHERE expires<=?').run(this.now());
    this.db.prepare('DELETE FROM sessions WHERE expires<=?').run(this.now());
  }

  close() { this.db.close(); }
}
