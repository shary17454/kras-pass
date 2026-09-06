# Apple account service

Deployed on the existing Kras Pass Railway service at
`https://kras-pass-production.up.railway.app`, with a persistent `/data` volume.
The Godot client is connected through the native iOS bridge. Real user Apple
authorization still requires an acceptance test on a signed device.

## Configuration

- `APPLE_CLIENT_ID`: native iOS bundle identifier, `com.shary.kraspass`.
- `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`: dedicated Apple sign-in
  credentials. The private key is stored only as a Railway secret, not in Git.
- `OWNER_EMAIL`: owner address, configured privately in the server environment.
- `ACCOUNT_DB_PATH`: SQLite file on persistent storage; do not use ephemeral
  deployment storage for the permanent Apple subject binding.
- `PORT`: HTTP port behind the deployment provider's HTTPS endpoint.

Use Node 24 or newer. `npm ci`, `npm test`, `npm start`.

## Flow

1. POST `/auth/apple/challenge` returns a nonce and challenge ID (five minutes).
2. The native Apple request uses the nonce unchanged and requests the email scope.
3. POST `/auth/apple/exchange` with `challenge` and `identity_token`.
4. The server verifies Apple's RS256 signature, issuer, audience, expiry, nonce
   and token age. Only a verified email can initially bind the owner subject.
5. The server returns an opaque, one-day session. Store it in iOS Keychain.
6. GET `/account` with a Bearer session to obtain `all_games`; POST `/auth/logout`
   invalidates that session. Returning owners retain access by Apple subject even
   when the email is absent. The client never sends an entitlement flag.
7. DELETE `/account` requires a new Apple authorization for the same subject and
   an active session. Exchange its code, validate the returned identity, revoke
   the Apple refresh token, then transactionally delete the account, owner
   binding and all sessions. Local gameplay progress is not server account data.

## Release gates still required

- Regenerate signing profiles for the newly enabled Apple capability and test
  real Apple login/cancel/logout/account deletion on a signed device.
- Update the public privacy policy and App Store privacy answers for user IDs.
- Review the sign-in button against Apple's design requirements before release.
- Add trusted edge rate limiting before broad use; the current socket limiter
  is intentionally conservative behind shared proxies.

Automated tests cover signed-token rejection, owner binding, replay, expiry and
deletion/session invalidation. Production health, challenge creation and
unauthorized rejection were checked separately. Neither proves an actual owner
authorization or Apple token revocation.
