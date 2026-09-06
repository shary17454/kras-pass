import {createServer} from 'node:http';
import {Accounts} from './accounts.js';
import {verifyAppleToken} from './apple.js';
import {revokeAppleAuthorization} from './apple-revocation.js';

const {APPLE_CLIENT_ID, OWNER_EMAIL, ACCOUNT_DB_PATH, PORT = '8080'} = process.env;
if (!APPLE_CLIENT_ID || !OWNER_EMAIL || !ACCOUNT_DB_PATH) {
  throw new Error('APPLE_CLIENT_ID, OWNER_EMAIL and persistent ACCOUNT_DB_PATH are required');
}
const accounts = new Accounts(ACCOUNT_DB_PATH, OWNER_EMAIL);
const appleConfig = {clientID: APPLE_CLIENT_ID, teamID: process.env.APPLE_TEAM_ID,
  keyID: process.env.APPLE_KEY_ID, privateKey: process.env.APPLE_PRIVATE_KEY};
const ready = Boolean(appleConfig.teamID && appleConfig.keyID && appleConfig.privateKey);
const limits = new Map();
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of limits) if (value.until <= now) limits.delete(key);
  accounts.prune();
}, 60000).unref();

function send(res, code, value) {
  res.writeHead(code, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
  res.end(JSON.stringify(value));
}

async function json(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 16384) throw new Error('Request too large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString());
}

const server = createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, {ok: true, authentication_ready: ready});
  // Socket-based throttling is deliberately conservative behind a proxy.
  // Do not trust caller-supplied forwarding headers for an authentication limit.
  const key = req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  let limit = limits.get(key);
  if (!limit || limit.until <= now) {
    if (limits.size >= 10000) return send(res, 503, {error: 'unavailable'});
    limit = {count: 0, until: now + 60000};
    limits.set(key, limit);
  }
  if (++limit.count > 60) return send(res, 429, {error: 'try_later'});
  try {
    if (req.method === 'POST' && req.url === '/auth/apple/challenge') {
      if (!ready) return send(res, 503, {error: 'unavailable'});
      return send(res, 200, accounts.challenge());
    }
    if (req.method === 'POST' && req.url === '/auth/apple/exchange') {
      if (!ready) return send(res, 503, {error: 'unavailable'});
      const body = await json(req);
      if (typeof body.challenge !== 'string' || typeof body.identity_token !== 'string') {
        return send(res, 400, {error: 'invalid_request'});
      }
      const nonce = accounts.nonce(body.challenge);
      if (!nonce) return send(res, 401, {error: 'sign_in_again'});
      const identity = await verifyAppleToken(body.identity_token, APPLE_CLIENT_ID, nonce);
      return send(res, 200, accounts.exchange(body.challenge, identity));
    }
    const token = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(req.headers.authorization || '')?.[1];
    if (!token || !accounts.access(token)) return send(res, 401, {error: 'sign_in_again'});
    if (req.method === 'GET' && req.url === '/account') return send(res, 200, accounts.access(token));
    if (req.method === 'DELETE' && req.url === '/account') {
      const body = await json(req);
      if (!ready || typeof body.challenge !== 'string' || typeof body.identity_token !== 'string'
          || typeof body.authorization_code !== 'string' || body.authorization_code.length > 4096) {
        return send(res, 400, {error: 'invalid_request'});
      }
      const nonce = accounts.nonce(body.challenge);
      if (!nonce) return send(res, 401, {error: 'sign_in_again'});
      const identity = await verifyAppleToken(body.identity_token, APPLE_CLIENT_ID, nonce);
      if (accounts.access(token).subject !== identity.subject) return send(res, 403, {error: 'wrong_account'});
      await revokeAppleAuthorization(body.authorization_code, identity, nonce, appleConfig);
      accounts.deleteAccount(token, identity.subject, body.challenge);
      return send(res, 200, {ok: true});
    }
    if (req.method === 'POST' && req.url === '/auth/logout') {
      accounts.logout(token);
      return send(res, 200, {ok: true});
    }
    return send(res, 404, {error: 'not_found'});
  } catch {
    // Never log identity tokens, email addresses or session credentials.
    return send(res, 401, {error: 'sign_in_failed'});
  }
});
server.requestTimeout = 15000;
server.headersTimeout = 10000;
server.listen(Number(PORT), '0.0.0.0');
process.on('SIGTERM', () => server.close(() => { accounts.close(); process.exit(0); }));
