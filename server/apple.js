import {createRemoteJWKSet, jwtVerify} from 'jose';

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export async function verifyAppleToken(token, audience, nonce, keys = appleKeys) {
  const {payload} = await jwtVerify(token, keys, {
    issuer: 'https://appleid.apple.com',
    audience,
    algorithms: ['RS256'],
    requiredClaims: ['sub', 'iat', 'exp', 'nonce'],
    maxTokenAge: '10m',
    clockTolerance: 5,
  });
  if (typeof payload.sub !== 'string' || !payload.sub || payload.nonce !== nonce) {
    throw new Error('Invalid identity');
  }
  const verified = payload.email_verified === true || payload.email_verified === 'true';
  return {
    subject: payload.sub,
    email: verified && typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : null,
  };
}
