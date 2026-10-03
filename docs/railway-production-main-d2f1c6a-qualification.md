# Current main production verification

Date: 2026-10-03. This is a new live observation, not reuse of the earlier
`567c308` deployment report.

## Source and deployment

- Repository: `shary17454/kras-pass`.
- Source branch: `main`.
- Commit: `d2f1c6af1e46dc578a2e501ec697e307d987a63a`.
- Project: `eb193205-199c-4aab-8aff-1bb532dfb4a3`.
- Production environment: `cb3cc392-8240-49a9-aeb6-e3894cace30b`.
- Service: `83908dbf-e4fe-4e99-9e55-0d8e0427cf58`.
- Deployment: `996db14a-f78b-40cc-817d-fe018d5fcba7`, `SUCCESS`.
- Created: `2026-10-03T13:42:36.618Z`.

Railway deployment metadata explicitly identified the repository, branch and
complete commit. This deployment already existed after the authorized main
push; another duplicate deploy was not created. The preceding `d177bb4` and
`7b617be` deployments were listed as REMOVED, not current production.

## Bounded log review and connectivity

One initial log retrieval failed with a Railway GraphQL connection reset.
A read-only retry for the same deployment succeeded. It was not an application
failure, deployment restart or a reason to infer missing production logs.

- Build: 49 JSON log records retrieved; no error/fatal severity or matching
  error/failed/fatal/uncaught message in that bounded sample.
- Deployment: 6 JSON records retrieved; no such errors; volume/startup markers
  were present at `2026-10-03T13:43:33Z`.
- `GET https://kras-pass-production.up.railway.app/health`: HTTP 200,
  `ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`.
- `GET /account` without credentials: HTTP 401, `sign_in_again`.

The six required Apple client/team/key/private-key, owner and account database
variables were present. Internal comparisons confirmed client/team/owner
alignment and a database path under `/data/`; raw values were never displayed
or stored in this report. Multiplayer is still disabled and an origin allowlist
is not configured. Do not enable public Internet rooms on this evidence alone.

`src/net/apple_account.gd` uses the tested production endpoint. This source
comparison and HTTP smoke are not a signed iPhone/TestFlight connection test.
No real Apple identity token was exchanged during these checks.

## Database verification

A read-only Railway SSH command opened the existing database with Node SQLite
`readOnly: true` and returned:

```json
{"quick":{"quick_check":"ok"},"foreignKeyErrors":0,"userVersion":{"user_version":0}}
```

No accounts, identities, tokens or rows were printed. Database files were not
recreated, migrated, reset or copied. `server/accounts.js` and Apple revocation
source have no diff between the previously verified `567c308` and this deployed
commit. No new account-schema migration was needed for that source transition.
This verifies structural integrity only, not backup restoration or all user's
entitlements. The existing schema still has user_version zero.

## Remaining work

This production source does not include the subsequent unmerged
`feature/kras-round-reward-integrity` client fixes. After approved integration,
verify that release source and deployed source again; do not label a feature
branch as production.

The 39-game balance campaign and main Game Quality checks are still live.
Production Internet multiplayer acceptance, origin configuration, real-device
auth/connectivity/performance/thermal/orientation tests, fresh Archive signing,
App Store upload/processing and review submission are not established here.
No Apple submission or change to certificates took place.
