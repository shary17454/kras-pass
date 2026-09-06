import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPair, SignJWT, createLocalJWKSet, exportJWK} from 'jose';
import {Accounts} from './accounts.js';
import {verifyAppleToken} from './apple.js';

test('deletion requires matching Apple subject and removes every account session', () => {
  const store = new Accounts(':memory:', 'owner@example.test');
  try {
    const owner = store.exchange(store.challenge().id, {subject: 'owner', email: 'owner@example.test'});
    const second = store.exchange(store.challenge().id, {subject: 'owner'});
    const other = store.exchange(store.challenge().id, {subject: 'other'});
    const challenge = store.challenge();
    assert.throws(() => store.deleteAccount(owner.token, 'other', challenge.id));
    assert.ok(store.access(owner.token));
    store.deleteAccount(owner.token, 'owner', challenge.id);
    assert.equal(store.access(owner.token), null);
    assert.equal(store.access(second.token), null);
    assert.ok(store.access(other.token));
    assert.equal(store.nonce(challenge.id), undefined);
    assert.equal(store.db.prepare('SELECT * FROM owner_binding').all().length, 0);
  } finally { store.close(); }
});

test('owner binding persists by subject, ordinary accounts stay locked, nonce cannot replay', () => {
  let now = 100;
  const store = new Accounts(':memory:', 'owner@example.test', () => now);
  try {
    const challenge = store.challenge();
    const owner = store.exchange(challenge.id, {subject: 'owner-sub', email: 'owner@example.test'});
    assert.equal(owner.all_games, true);
    assert.throws(() => store.exchange(challenge.id, {subject: 'owner-sub'}));
    const returning = store.exchange(store.challenge().id, {subject: 'owner-sub', email: null});
    assert.equal(returning.all_games, true);
    const stranger = store.exchange(store.challenge().id, {subject: 'stranger', email: null});
    assert.equal(stranger.all_games, false);
    const changed = store.exchange(store.challenge().id, {subject: 'other-sub', email: 'owner@example.test'});
    assert.equal(changed.all_games, false, 'email cannot silently replace a bound Apple subject');
    store.logout(owner.token);
    assert.equal(store.access(owner.token), null);
    now += 86401;
    assert.equal(store.access(returning.token), null);
  } finally { store.close(); }
});

test('expired challenge is denied', () => {
  let now = 1;
  const store = new Accounts(':memory:', 'owner@example.test', () => now);
  const challenge = store.challenge();
  now = 302;
  assert.equal(store.nonce(challenge.id), undefined);
  assert.throws(() => store.exchange(challenge.id, {subject: 'a'}));
  store.close();
});

test('Apple signature, audience, issuer, nonce, expiry and verified email are enforced', async () => {
  const {publicKey, privateKey} = await generateKeyPair('RS256');
  const jwk = await exportJWK(publicKey);
  jwk.kid = 'test';
  const keys = createLocalJWKSet({keys: [jwk]});
  const make = (overrides = {}, key = privateKey) => new SignJWT({
    sub: 'apple-user', nonce: 'challenge', email: 'owner@example.test', email_verified: true,
    iss: 'https://appleid.apple.com', aud: 'com.shary.kraspass',
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300, ...overrides,
  }).setProtectedHeader({alg: 'RS256', kid: 'test'}).sign(key);
  const verify = async overrides => verifyAppleToken(await make(overrides), 'com.shary.kraspass', 'challenge', keys);
  assert.equal((await verify({})).email, 'owner@example.test');
  assert.equal((await verify({email_verified: false})).email, null);
  for (const bad of [{aud: 'another-app'}, {iss: 'attacker'}, {nonce: 'old'}, {exp: 1}, {sub: ''}]) {
    await assert.rejects(verify(bad));
  }
  const other = await generateKeyPair('RS256');
  await assert.rejects(verifyAppleToken(await make({}, other.privateKey), 'com.shary.kraspass', 'challenge', keys));
});
