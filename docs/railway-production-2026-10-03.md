# Railway production synchronization: 2026-10-03

## Verified source and deployment

- Repository: `shary17454/kras-pass`; source branch: `main`.
- Deployed commit: `567c308e3e9d94acb977567a76106f1e6931b2e9`.
- Project: `eb193205-199c-4aab-8aff-1bb532dfb4a3`.
- Production environment: `cb3cc392-8240-49a9-aeb6-e3894cace30b`.
- Service: `83908dbf-e4fe-4e99-9e55-0d8e0427cf58`.
- New deployment: `b67de6f1-fa19-4cbf-8e66-3bc96530c0a6`, status `SUCCESS`.
- Previous deployment: `01d945d4-1d0f-4cb4-9514-9bd73db7ac63`,
  commit `c61005fd33e3821323379b56d9cfedd4a7407ce0`.

The initial live status proved production was stale. Explicitly connecting
the existing service source to this repository and branch created a new
GitHub-sourced deployment. It was not a redeploy of the old image or an upload
of an uncommitted directory. Deployment metadata confirmed the full commit.

Build logs confirmed Dockerfile execution, Node 24-slim, `npm ci --omit=dev`,
server copy and `/app/data/minigames.json` copy. The initial BUILDING metadata
briefly showed Railpack; actual build logs resolved that ambiguity. Runtime
logs confirmed persistent volume mount and `node index.js` startup. No build
or startup failure was found in the bounded logs inspected.

## Environment and storage

Required Apple client/team/key/private-key, owner and database-path variables
are present. Values were consumed internally and not printed. Client ID and
team match `com.shary.kraspass` and `4HM66AD594`. SQLite is configured under
the existing `/data` persistent volume, which was READY and not pending deletion.
The service retains one replica; no database or account was recreated.

Production Online remains disabled. No multiplayer origin allowlist is set;
that must be configured and tested before enabling Internet rooms. This sync
does not substitute disabled networking for the requested final Online scope.

The account/schema and Apple verification/revocation source files have no diff
between the old and new production commits. Their existing idempotent table
creation remains in place; no separate schema migration was needed for this
deployment. A read-only SSH check in the running production container returned:

- SQLite `PRAGMA quick_check`: `ok`.
- `PRAGMA foreign_key_check`: zero errors.
- `PRAGMA user_version`: zero (current account schema has no version marker).

This verifies current database structural integrity, not a backup restore test
or the correctness of every user's entitlement.

## Post-deploy API checks

Endpoint: `https://kras-pass-production.up.railway.app`.

- `GET /health`: 200, `ok=true`, `authentication_ready=true`,
  `multiplayer_enabled=false`.
- `GET /account` without credentials: 401, `sign_in_again`.
- `POST /auth/apple/challenge`: 200, correctly typed challenge and nonce with
  integer expiry; no nonce/token printed. This writes only an expiring challenge,
  not an account or owner entitlement.

The client Apple service points to this endpoint. Actual signed iPhone Apple
login, cancellation, logout, deletion and connection still need acceptance QA.
No browser OAuth callback/webhook feature is defined by these native routes;
other production integration requirements remain subject to the release audit.

## Remaining release and operations gates

Railway warns that `railway.json` configuration is deprecated and existing
files keep working until 2026-12-01. This warning did not fail deployment;
Infrastructure-as-Code migration needs a reviewed plan before changing live
resource ownership. Do not automatically migrate/delete the persistent volume.

Rollback target is the previous verified deployment/commit above. A rollback
has not been executed or tested, and it must preserve `/data`. Live alert
configuration, sustained performance and backup restoration are not proven.

The all-game real-peer CI matrix and latest-main CI are still pending. This
report does not prove all product requirements, physical-device FPS/thermal
behavior, an Xcode archive, distribution signing, App Store upload/processing,
or review submission. No Apple submission occurred during this sync.

## Recheck commands

Use explicit project/environment/service selectors shown above with
`railway deployment list --json`, `railway logs DEPLOYMENT --build --lines 80`
and `railway logs DEPLOYMENT --deployment --lines 40`. Filter deployment
metadata to ID/status/commit before reporting it. Never print raw variable JSON,
account data, private keys or bearer sessions.
