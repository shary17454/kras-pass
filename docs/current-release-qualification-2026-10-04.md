# Current Release Qualification

## Source

Repository: `shary17454/kras-pass`, remote `origin`, branch `main`.
Integrated source: `f29824f82d6f34d6d5e4b090befa17e792be6f94`.
The merge has an identical tracked tree to
`b345203cc2f19d9cf6271cdc83cdf5c4e82ae257`; `git diff --exit-code`
confirmed this after integration. This does not identify an App Store build.

## Collection Balance Evidence

The previous immutable Linux core run `37170895944`, job `111343465474`,
failed: 29749 assertions passed, one failed. Expert gem collection scored 60
against Easy 62. That source must not be described as a passing full suite.

The collector correction uses delayed observed opponent motion to distinguish
approaching competition from a competitor moving away. Unknown or hidden
opponents do not influence selection. No character stats, difficulty bonuses,
test comparison thresholds or campaign flags were changed.

The natural comparison used identical eight baseline seeds, sixteen mirrored
difficulty matches across all eight characters, two mutator/chaos matches,
seed offset 300000 and an 85-second ordinary round window.

- Before: `/tmp/kras-9d70e97-gem-natural-report/report.json`, Expert place-share
  0.5, retained flag `expert bots no better than easy`.
- After: `/tmp/kras-collector-motion-natural-after-report/report.json`, Expert
  place-share 0.574850299401198, no flags in this sample; all 26 matches completed.
- Both engine logs passed `tools/check_godot_log.sh` in runtime mode.

This is a limited matched sample for one minigame, not the required full
42-match-per-game campaign and not statistical proof of all-game balance.

Focused source checks passed: observed-motion 8 assertions, shared visibility
2085, party 4117, original difficulty-only 3 (16 matches), balance reporting 504,
and compilation of 331 scripts. Logs use `/tmp/kras-collector-motion-*`.

## Actual Engine/Server Capture Checks

Fresh isolated Godot capture suites passed with positive summaries and log guards:

| Suite | Assertions |
| --- | ---: |
| armed_race_network | 176 |
| colossus_network | 152 |
| siege_network | 129 |
| dreadnought_network | 117 |
| sovereign_network | 141 |
| forge_network | 141 |

All six actual captures were supplied through the existing `KRAS_*_WORLD_FIXTURE`
environment variables to `npm test`. Result: 179 passed, zero failed and zero
skipped. Log: `/tmp/kras-collector-motion-server-captures.log`.
These are engine/server schema integration checks, not four humans over Internet.

## Production Inspection

Railway deployment `09dbb459-ee9e-4784-9af4-c84f838b7cd9` is `SUCCESS`, with a
`RUNNING` instance, repository `shary17454/kras-pass`, branch `main`, and exact
commit `f29824f82d6f34d6d5e4b090befa17e792be6f94`.
The `/data` volume is `READY`. `/health` returned `ok=true`,
`authentication_ready=true`, `multiplayer_enabled=false`.
The last 100 requested deployment log entries contained container startup and
`node index.js`, with no error shown. This small sample does not prove that all
API routes, backups, migrations or authentication callbacks are correct.

The effective deployment manifest reports `healthcheckPath=null` and
`healthcheckTimeout=null`, although tracked `railway.json` specifies `/health`
and 100 seconds. This production configuration mismatch requires diagnosis and
verification before relying on Railway's health gate. No production variable or
certificate was changed during these checks.

## Open Gates

Main quality run `37172568945` targets the exact integrated commit. At inspection,
core and networking jobs were in progress or queued; no passing full result is
claimed. The physical iPhone 16 Pro Max was `unavailable` in a fresh Xcode 27
device inspection. Simulators are not physical performance/thermal/battery proof.

Remaining work includes full immutable-source CI, all-game balance, outstanding
product requirements, Internet multiplayer, physical portrait/landscape QA,
production health configuration, API/auth/database/backup checks, and exact-source
Distribution archive/signature/upload/processing/review submission.
No new archive, upload or Apple review submission occurred in this qualification.

## Subsequent Production Health Correction

The live Railway GraphQL schema was inspected before a bounded
`serviceInstanceUpdate`: only `healthcheckPath=/health` and
`healthcheckTimeout=100` were supplied, with explicit production service and
environment IDs. No infrastructure ownership migration, volume change,
secret update, replica change or multiplayer enablement was performed.

Re-reading `serviceInstance` confirmed both values were saved. An ordinary
redeploy (`2ab72eb7-1af9-4f50-930e-51479738947e`) succeeded but reused the old
deployment manifest with null health settings. It therefore did not prove the
health correction was applied. A subsequent `--from-source` deploy resolved
the current service configuration from the verified GitHub source instead.

Deployment `79d21f7c-65f3-4ca8-a322-85d1f38c3692` reached `SUCCESS`, exact
commit `f29824f82d6f34d6d5e4b090befa17e792be6f94`. Its effective manifest
contains `/health` and 100 seconds. Actual build logs explicitly record:
`Starting Healthcheck`, `Path: /health`, `Retry window: 1m40s`, and
`[1/1] Healthcheck succeeded!`. This resolves the health configuration gate,
not the remaining production multiplayer and release acceptance gates.
State evidence: `/tmp/kras-health-from-source-state.json`.

A read-only SSH SQLite check returned `PRAGMA quick_check=ok`, zero
foreign-key errors, and `user_version=0`. The first SSH invocation had a local
command-quoting error; the corrected command completed successfully without
changing the database. Database version zero is the existing account schema,
not proof of a versioned migration or backup-restore strategy.

Production API probes: unauthenticated `GET /account` returned 401 with
`sign_in_again`; `POST /auth/apple/challenge` returned 200 with string `id`,
string `nonce`, and integer `expires`, without printing their values. The first
probe incorrectly expected a field named `challenge`; it was corrected against
the actual `Accounts.challenge()` contract. These probes do not authenticate a
real Apple user or prove deletion, revocation or owner entitlements on a phone.

## Subsequent Exact-Source CI Result

The `godot` job `111348417130` in run `37172568945` completed successfully
against the integrated commit. Its downloaded log is
`/tmp/kras-f29824f-core-job.log` and confirms compilation of 331 scripts,
`ALL TESTS PASSED` with 29797 assertions, and 117 stability matches with zero
failures. Initial server tests passed 173 with six fixture skips; the subsequent
actual-capture validation passed all 179 with zero skips. Do not report the
initial skipped run alone as full capture coverage.

The `network-ring_rumble` and `network-goal_guard` jobs also completed
successfully. Remaining network jobs were still running or queued at inspection.
This is not a passing 39-game network matrix, rendered visual QA, or an Apple
review submission. Earlier pending statements above record their inspection
time and are superseded only for the specific gates verified in this section.
