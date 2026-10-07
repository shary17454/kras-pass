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
