# Active Online Match Version Recovery

Test source: `274f8d381d06fa9e2c66ce26d6195298a5796d8a`.
Parent/runtime: `82f3a7692b8f61b341fb26d69b3170c3a82496cd`.
Branch: `test/kras-active-match-version-recovery`.

The previously documented terminal version-error behavior already exists.
This change adds integration coverage rather than duplicating that code or
claiming a new runtime fix.

The test mounts the actual online match through SceneRouter, captures a valid
presentation snapshot, changes the fixture's phase to PLAYING, and delivers
it through Net._receive and the real guest replica/render pipeline. It checks
that the match has reached PLAYING before injecting each terminal entry path:
transport protocol_mismatch and server version_mismatch.

Both paths must return to the actual room browser, free the match and its world,
leave exactly one screen, preserve the localized incompatibility message,
cancel retries and clear the resume token. Statistics, the replay index and
profile data must remain unchanged. A fresh local session and local-play route
must work afterward. No external endpoint is contacted by these fixtures.

## Qualification

- Initial mounted-route network suite: 260 assertions pass.
- Expanded live guest snapshot suite: 262 assertions pass in 1.9 seconds.
  Logs: /tmp/kras-active-version-playing.log and
  /tmp/kras-active-version-playing-engine.log. Strict completed-test guard passes.
- Full check_party.sh at test source: exit 0, 422 scripts compile, 522 resources,
  22 autoloads, 27 routes, 8 characters, zero inventory issues.
- Full test suite: 390535 assertions pass in 274.6 seconds.
- Authored race check and six boss regressions pass.
- Stability: 39 matches, zero failures. All eleven engine logs also pass the
  stricter import-mode ERROR guard (completed-test mode for tests).
- Full log: /tmp/kras-active-version-full-check.log.
- Evidence directory:
  /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.KFuAne.

No product runtime, rules, RNG, thresholds, production settings, or main branch
changed. The local Xcode 27 archive remains the separately verified candidate
1.1.11 (112), source 826d4ca39fc06ffdb70443c691f456336339a497. These test-only
changes are not claimed to be inside that earlier archive.

## Current Balance Evidence And Release Limits

Campaign 37694780646 uses runtime 82f3a7692b8f61b341fb26d69b3170c3a82496cd
and offset 1200000. Downloaded tank_arena, ring_rumble and crumble_court reports
pass exact source/run/paired seed-character validation: 126 completed matches,
three of 39 games, not a completed campaign. Runtime fingerprint:
d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e.

Tank and Ring report no balance flags. Crumble reports spawn slot advantage:
baseline seat wins [8,4,12,0], slot bias 0.25, Expert edge 0.56875. This warning
is retained; it does not establish the cause and was not hidden by changing
thresholds. Artifact root: /tmp/kras-current-partial-campaign-37694780646.
The first single-artifact download used the root directory; it was reorganized
into its game subdirectory before the three-game aggregate validation. A guard
invoked against the initially absent subdirectory failed; the corrected log
path passed. No engine result was discarded.

The previously verified four-client Tank tournament is local WebSocket evidence,
not production Internet or physical-device qualification. Production /health
still reports multiplayer_enabled=false. Current-source full balance, Crumble
investigation, physical iPhone/iPad controls/performance/energy, production
connection/auth/subscription, and App Store session/build selection remain
release gates. No merge, Railway change, upload or App Review submission occurred.

## Follow-up: Crumble Independent Sample

No runtime change was made. At documentation source
693de60d606caae98939b45aa7fb6dcfdacab832, a natural trace with seed 1209001
and the original first-baseline roster [nabta,sakhra,fanoos,ramla] finished
in 10.0667 simulated seconds with scores [6,2,10,4]. Initial spawn positions
were cardinally symmetric. This single trace does not establish the cause of
the observed campaign seat distribution.

Trace log: /tmp/kras-crumble-current-trace-1209001.log. Its engine log passed
the strict import-mode guard. The surviving fighter continues falling during
FINISH after the round has already resolved; this is presentation evidence,
not a second elimination or evidence that its awarded result is wrong.

An independent natural sample used offset 1500000, unchanged runtime,
24 rotated-character baselines, 16 matched-seed/character difficulty matches,
and two mutator stress matches. Exit 0, official Godot 4.7.1, unchanged
start/end runtime fingerprint, strict engine guard passes, both stress runs pass.
Baseline seat wins [6,9,5,4], seat bias 0.125, character bias 0.083333,
no ties, average duration 13.5 seconds, Expert edge 0.50625. The report retains
the warning "expert bots no better than easy". The original sample's seat
warning was NOT replaced or declared fixed. One changed leading seat is not
proof of fair spawning; it does weaken the claim of a single established cause.

Independent log: /tmp/kras-crumble-heldout-1500000.log. Raw independent and
original reports are retained under docs/qa/crumble-current-2026-10-08/.
No thresholds, game rules, timing, physics, AI perception or RNG were altered.
Route/escape decisions and difficulty separation require investigation before
a qualified behavior change can be accepted.

The current campaign also completed bumper_bowl, fawda and goal_guard.
Six reports now pass exact source/run/offset and paired-difficulty validation:
252 matches, six of 39 games. Of these reports, only Crumble records a balance
warning. New simulation logs pass the strict engine guard. The campaign remains
live and incomplete; no restart/cancellation was performed.

Current-source content audit incorporating those six reports and the existing
Hurdle report: READY 0, NEEDS_POLISH 6, NEEDS_BALANCE 33, REWORK 0, BROKEN 0.
The local-session audit and strict guard passed:
/tmp/kras-current-six-audit.log and /tmp/kras-current-six-audit-engine.log.
Missing/currently inadequate evidence does not mean all 33 games are proven
unbalanced. Real-device approval/QA, source promotion, production qualification,
and App Store Connect availability remain open. No release submission occurred.
