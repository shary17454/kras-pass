# Current server and production gates

Development checkout: `/tmp/kras-crate-swing-arbitration`,
`fix/kras-magnet-swept-capture-order`,
`fc7c3de868135be2d4f965f8e885bd5b7bf07087`.
No runtime changed since the qualified Magnet source `d854d69`.

## Safe local checks completed

- Server: 204 tests pass, zero failed/skipped, including migrations/rollback,
  backup/WAL integrity, Apple-token validation, owner binding, authoritative
  results, room limits, protocol versions and reconnect.
- Six actual Godot world captures supplied from the current full gate
  `kras-party-check.PF93DI/saves-tests`: armed, siege, forge, dreadnought,
  sovereign and colossus. These are current runtime fixtures, not fabricated
  JSON or old integrated-source captures.
- Infrastructure: 22 tests pass, zero failed/skipped. An initial attempt failed
  because the root `railway` package was absent. `npm ci --ignore-scripts
  --no-fund` installed the exact lockfile dependencies; no source or lockfile
  changed, and no infrastructure apply occurred. Re-run passed.
- `npm audit --omit=dev --audit-level=high` in `server` found zero known
  vulnerabilities; root dependency installation also reported zero. This is
  dependency-advisory evidence, not a complete security certification.

Saved logs: `/tmp/kras-magnet-current-server-tests.log` and
`/tmp/kras-magnet-current-infra-tests.log`.

## Fresh production metadata, not a new deployment

Read-only Railway status and deployment listing confirm:

- Project `eb193205-199c-4aab-8aff-1bb532dfb4a3`.
- Environment `cb3cc392-8240-49a9-aeb6-e3894cace30b` (`production`).
- Service `83908dbf-e4fe-4e99-9e55-0d8e0427cf58` (`kras-pass`).
- Repository `shary17454/kras-pass`, branch `main`.
- Deployment `8d235c0c-eac1-4ade-9065-4e3264d36021`, SUCCESS, running instance,
  created `2026-10-06T01:59:33.330Z`.
- Deployed commit `062a40992b92958573e28e19d8c8c1840560797a` matches freshly
  fetched `origin/main`. Development fixes are not on that production source.
- Docker build, `/health` health check, one `ams` replica, `/data` volume READY.

The first deployment-list attempt used an incorrect service identifier and was
rejected as not found. A fresh project status provided the actual service ID;
the corrected read succeeded. No resource was created, linked, changed or
redeployed during these calls.

Requested the latest 100 deployment log rows and received six, all info level,
from `2026-10-06T02:00:35.573456659Z` through
`2026-10-06T02:00:36.319573226Z`; no error/fatal/exception/unhandled text was
found in this sample. Only counts and timestamps were printed, not log contents.
This small retained startup sample cannot establish absence of later errors or
qualify a new deployment that has not happened.

Latest read-only `/health`: `ok:true`, `authentication_ready:true`,
`multiplayer_enabled:false`. Production online acceptance is still incomplete.

## Not completed / external gates

Requested specific approval for a temporary in-Railway production account
backup/restore rehearsal, with no Mac download, no data display, no live DB
writes and no migrations under that permission. No approval response was
received in this pass; no production account data was read or copied.
Even a successful temporary rehearsal would not constitute a durable encrypted
backup/retention policy. Source promotion, protected production data operations,
schema rollout, positive native auth/subscription, Internet multiplayer, and
device portrait/landscape/energy/performance acceptance remain outstanding.

No main merge, deployment, secret change, migration, online enablement, native
archive rebuild, App Store upload or review submission occurred. Candidate 112
does not contain the new Magnet runtime change and must not be reused as its
release evidence. Local Xcode 27 remains the required build path.
