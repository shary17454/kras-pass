# Railway Plan Integrity Qualification

## Source and production

- Production repository: `shary17454/kras-pass`, branch `main`.
- Deployed commit: `e1c5e34b933115403f7cff838e3cfd88e1af8a90`.
- Deployment: `6952a3b2-2ac9-42b8-a6dd-6ef2029053e3`, status `SUCCESS`.
- Project: `eb193205-199c-4aab-8aff-1bb532dfb4a3`.
- Environment: `cb3cc392-8240-49a9-aeb6-e3894cace30b`, `production`.
- Service: `83908dbf-e4fe-4e99-9e55-0d8e0427cf58`.

These are live observations, not evidence of an iOS archive or App Store upload.

## Guard regression

The initial guard accepted four unreported edits: networking, tracing, service
name and grouping. Six adversarial cases produced 24 passes and four failures
out of 28 tests. Runtime and build-environment edits were already rejected by
the exact desired-settings check.

The corrected guard compares every service field except the seven reviewed
build/deploy properties, then separately verifies all other build and deployment
fields. The authoring file explicitly retains the production domain on port
8080, build environment V3, runtime V2, IPv6 egress setting and stacker setting.
The real current/desired graph comparison passes, not just synthetic fixtures.

- `npm run test:infra`: 29 passed, zero failed, skipped or cancelled.
- `git diff --check`: passed.
- Fresh raw Railway plan: exactly two safe updates; no diagnostics.
- `node .railway/check-plan.mjs /tmp/kras-railway-integrity-plan.json`: passed.
- Root `railway.json` remains unchanged. No configuration apply was performed.

Local evidence: `/tmp/kras-iac-guard-adversarial-baseline.log` and
`/tmp/kras-railway-integrity-plan.json`. Plans contain preserved variable markers,
not secret plaintext. Do not use an old plan after the environment revision or
source tree changes; generate and validate a fresh pinned plan for the cutover.

## Live service checks

Four requests passed expected status and response assertions:

| Request | Status | Scope |
| --- | --- | --- |
| GET `/health` | 200 | `ok=true`, authentication ready |
| GET `/account` without credentials | 401 | Unauthenticated access rejected |
| POST `/auth/apple/exchange` with empty object | 400 | Missing fields rejected |
| POST `/auth/apple/challenge` | 200 | Challenge issued, values not logged |

Evidence: `/tmp/kras-railway-e1c5e34-api.log`.
The challenge request creates only a normal short-lived authentication challenge;
it does not log in, create an account, or prove Apple identity exchange.

Read-only SSH accessed the actual deployed container and opened
`/data/accounts.sqlite` with SQLite readOnly and query_only enabled:

- `PRAGMA quick_check`: `ok`.
- `PRAGMA foreign_key_check`: zero errors.
- Tables: accounts, challenges, owner_binding, sessions.
- `PRAGMA user_version`: 0. This is an observed existing schema version, not a
  claim that versioned database migrations have been implemented.
- Persistent volume remains READY, 5000 MB, mounted at `/data`.

The retrieved runtime log contains container start and `node index.js`, with no
error in that bounded snapshot. CLI emits a legacy-configuration deprecation
warning; the infrastructure cutover remains incomplete. The snapshot does not
prove the entire historical log is error-free, load performance, or backup restore.

## Remaining release gates

- Production multiplayer remains disabled; `/health` reports false.
- Real Apple sign-in and app-to-production exchange remain unqualified.
- Browser Apple session is still at sign-in, not authenticated portal access.
- Current main Game Quality run `37156398701` is live, not a completed pass.
- Infrastructure Quality run `37156398583` passed for deployed commit e1c5e34.
- No new signed archive, App Store upload, processing or review submission.
- Physical multiplayer, controllers, orientation, thermals and battery QA remain
  necessary. Neither API health nor headless tests replace those checks.

Official migration reference: https://docs.railway.com/infrastructure-as-code
