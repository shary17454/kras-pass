# Walk Before Jump Qualification

Frozen runtime: `63ffa42f77e7f9865aade45fb691f06a2fa43ab3`.
Parent: `aed4fe8dd9c3720195bdaa1df94c9fac2a6ee0a7` (PR114).

Platform bots previously jumped as soon as their warning reaction elapsed,
even when a visible fresh tile was reachable by walking. Route selection now
precedes the jump decision. A fresh, visible first step retains ordinary
ground movement; trapped or warning-only routes retain rescue jumping.
No movement statistics, reaction profiles, private floor information or
authored timers were changed. Human Crumble Court controls include jump.

## Tests On Frozen Source

- Ground routing regression: red 40 pass / one fail; green 41 pass.
  `/tmp/kras-walk-jump-{red,green}.stdout`.
- Perception: 2091 pass. `/tmp/kras-walk-jump-perception.stdout`.
- Full release gate: 366163 assertions in 306.9 seconds; 390 scripts,
  434 resources, 22 autoloads, 27 routes, eight characters, no inventory
  issues. Three-lap and six boss probes pass; 117 stability matches, zero
  failures. Settled static memory 133588697 bytes (not RSS/GPU memory).
  `/tmp/kras-walk-jump-final-release-gate.stdout`, evidence directory
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.jCNW8j`.
- Server: 192 pass, zero failures or skips, using the gate's actual world
  captures. `/tmp/kras-walk-jump-final-server.stdout`.
- Natural independent campaigns: 42 matches each, 84 total. Offset 600000:
  mean 12.183333 seconds, Expert share 0.543750. Offset 900000: mean
  12.255556 seconds, Expert share 0.562500. Both reports have no review flags.
  Reports: `/tmp/kras-walk-jump-natural-report/report.json` and
  `/tmp/kras-walk-jump-independent-report/report.json`. Limited samples do
  not certify balance; pacing and authentic human play remain unresolved.
- Actual local network smoke passes with two automated humans plus two bots
  and four automated humans, including host/client reconnection and matching
  results. Four-human scores `[4,8,14,14]`, client world counts 701/682/701.
  Event-loop monitor maximum 63 ms. This ran alongside native rendering,
  not as an isolated latency benchmark or production Internet test.
  `/tmp/kras-walk-jump-final-network.stdout`.

All owned qualification processes reached exit zero before this document.
Tracked runtime remained unchanged throughout these checks.

## Native Visual Findings

Actual macOS Metal/Mobile render, Arabic, one touch human plus three bots,
default arena of all 39 games, portrait and landscape: 78 nonblank captures
and zero image-check failures. The first run nonetheless logged seven
ObjectDB instances leaked at exit, so its strict console guard FAILED.
`/tmp/kras-walk-jump-all39-visual.{stdout,log}`.

A focused Crumble Court run and the full verbose repeat did not reproduce
the leak. The verbose repeat produced 78 captures, zero image-check failures
and passed the console guard. This is an intermittent unresolved finding,
not a root-cause fix. `/tmp/kras-walk-jump-all39-verbose.{stdout,log}`.

Manual inspection of four landscape captures found the rear player hidden
by the Colossus boss and partly covered by Crumble Court's hover machine.
Counting four fighter nodes does not establish visual visibility. The other
74 images were not manually certified. No physical-device, four-hand,
thermal, battery, every-map or full-round visual acceptance is claimed.

## Release Boundary

No main merge, Railway deployment, online activation, current-source signed
archive, App Store upload or review submission occurred. Final Apple work
must use local Xcode 27 and the existing Keychain Distribution identity,
without importing P12. This qualification does not complete the broader
product requirements or authorize bypassing remaining release gates.
