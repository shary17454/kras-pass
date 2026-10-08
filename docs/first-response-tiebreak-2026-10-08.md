# First-Response Tournament Decider

Source commit: `4662efe06e653ebb0f0a1c8d80bfe20b35671699`.
Branch: `feat/kras-first-response-tiebreak`; repository: shary17454/kras-pass.
Runtime fingerprint: `39854bc0220d9911c43a4fce98c0d35dcc562dae73d196c9475c213c06d98e93`.
Evidence: `qa/first-response-tiebreak-2026-10-08/`.

## Change

The local tournament's dedicated Quick Draw decider previously accumulated
signals until its 20-second timer expired. It now completes after the first
signal that awards points. The existing finish/results lifecycle runs normally;
the aggregate remains eligible for tournament completion and original-slot
remapping. Ordinary Quick Draw rounds are unchanged.

Same-tick responses keep their shared rank. False starts and unanswered signals
do not award a win; the existing timeout remains. Repeated true ties still use
the tournament's bounded retries/shared-champion fallback, not an arbitrary
slot-order winner. This does not change the online tournament ruleset, which
uses its configured game for deciders rather than this local-only rule.

## Verification

- Before the runtime change: 66 assertions passed, five first-response assertions
  failed on the preceding behavior. This is the retained valid red run.
- Final focused lifecycle: 82 assertions pass, including all four first-response
  slots, simultaneous responders, false starts, no response, ordinary-game
  continuation and real FINISH/RESULTS/DONE delivery to the tournament.
- Local party systems: 4171 assertions pass.
- Quick Draw network state: 85 assertions pass.
- All 423 scripts compile.
- Full suite on the source commit: 392025 assertions pass, exit zero, 306.5s.
  Existing log guards pass; intentional save-write/router-load error fixtures
  remain in the raw full-suite log. Do not call it error-free.

The separate natural probe ran eight actual AI deciders, with two/four
contenders and four seeds. All eight completed one signal/resolution, retained
positive clock time, produced eligible results and completed the tournament.
Live-round duration was 2.5333-4.3167 seconds. Initial tournament ties were
synthetic; decider input came from actual AI and the normal physics lifecycle.
This is not physical-human, balance-population or phone-performance evidence.

The first temporary probe failed on a typed-array assignment in its own script
and was explicitly terminated (143). Its failed log is retained. The corrected
probe independently completed with zero failures and passed the runtime guard.
Neither retry changed game source. An earlier invalid suite-filter invocation
selected zero suites and is not counted as red regression evidence.

## Remaining Release Gates

The parent source's campaign 37730069685 has eleven inspected artifacts,
462 natural baseline/difficulty/stress matches and no flags in those artifacts;
the full 39-game campaign remains incomplete. Its fingerprint is 160a0600...,
not this new source, so it cannot certify this commit or a release.

Current readonly production health: ok=true, authentication_ready=true,
multiplayer_enabled=false. No deployment, database copy, certificate change,
archive, upload or review submission occurred. Physical-device installation and
production encrypted-backup approval have been requested, not assumed granted.
The older unsigned 7f270c5 native preflight lacks this change and must not be
uploaded as the latest release. Final-source qualification, stable phone
performance, production synchronization and positive native connectivity,
signed local Xcode 27 archive, upload/processing and App Review remain open.
