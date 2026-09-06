import {importPKCS8, SignJWT} from 'jose';
import {verifyAppleToken} from './apple.js';

export async function revokeAppleAuthorization(code, identity, nonce, config) {
  const key = await importPKCS8(config.privateKey.replaceAll('\\n', '\n'), 'ES256');
  const secret = await new SignJWT({})
    .setProtectedHeader({alg: 'ES256', kid: config.keyID})
    .setIssuer(config.teamID).setSubject(config.clientID)
    .setAudience('https://appleid.apple.com').setIssuedAt().setExpirationTime('5m')
    .sign(key);
  const post = async (path, fields) => {
    const response = await fetch(`https://appleid.apple.com/auth/${path}`, {
      method: 'POST', signal: AbortSignal.timeout(10000),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams({client_id: config.clientID, client_secret: secret, ...fields}),
    });
    if (!response.ok) throw new Error('Apple authorization could not be revoked');
    return response;
  };
  const tokens = await (await post('token', {code, grant_type: 'authorization_code'})).json();
  const confirmed = await verifyAppleToken(tokens.id_token, config.clientID, nonce);
  if (confirmed.subject !== identity.subject || typeof tokens.refresh_token !== 'string') {
    throw new Error('Apple account mismatch');
  }
  await post('revoke', {token: tokens.refresh_token, token_type_hint: 'refresh_token'});
}
