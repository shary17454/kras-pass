# Platform ground routing qualification

Parent release source: `cb692323bd44214dde54a74a036078e1a457300e`.
Runtime correction: `75afb58` on `fix/kras-platform-ground-routing`.
Visibility fixture correction: `6b342c8`.
Rendered QA harness correction: `f4a2aa6ad0d4ea3015210fa6b4fdd89679ad7abc`.
Final runtime qualification source: `6527fc4944dc4d1718b826650a926aa99a6fe7a6`.

## Reproduced defect and correction

Platform bots previously selected a visible solid destination without checking
whether intact ground connected it to their current tile. A straight steering
vector could cross a disappeared tile or cut diagonally through its corner.
The isolated routing fixture reproduced four failures on the original code,
with no script errors after supplying its required MatchConfig.

The selector now walks a cardinal connectivity graph of visible, standable
tiles within its existing 12-unit planning range and returns the first route
step, not a distant destination. Falling, gone and hidden tiles cannot connect
the graph. Warning tiles remain traversable while their collision still exists.
No hidden collapse timers, rival data, movement bonuses or extended vision are
introduced. An absent route no longer steers blindly toward the arena origin.
The routing-only focused fixture passes seven assertions including runner selection.

The pre-existing visibility fixture lacked any visible floor under the bot.
It now supplies a visible warning origin and a cardinally adjacent destination;
its hidden-target, hidden-neighbour and cached-target assertions are retained.
The focused visibility suite passes 2085 assertions.

## Actual gameplay comparison

Natural sample: 24 baseline rounds, 16 seed/character-matched difficulty rounds,
two mutator/chaos checks, offset 600000, all completed. Durations and balance
thresholds are unchanged. Report:
`/tmp/kras-platform-balance-report/report.json`; log:
`/tmp/kras-platform-balance.log`. Engine and log guard exit 0.

Mean duration is 6.308333 seconds, character bias 0.083333, slot bias 0.083333,
Expert score share 0.625, no ties or missing outcomes. Both mutator checks pass.
The ongoing parent campaign printed approximately 6.0 seconds and 21 percent
slot bias for this game. Its complete JSON report is still pending, so those
rounded values are not substituted for an exact paired-report comparison.
The short duration remains a polish issue despite empty automated flags.
This correction does not establish a 30-second-plus, entertaining round,
representative independent-seed balance, or READY status.

## Regression and rendered harness

`/tmp/kras-platform-full-final.log` completed with exit 0. Artifacts:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.6sjCYl`.
384 scripts compile; inventory covers 424 resources, 21 autoloads, 27 routes,
eight characters and zero structural issues. Unit/integration stage:
360627 assertions pass. The separate three-lap regression and six boss checks
pass. Stability completes one cycle through all 39 games with zero failures;
ordinary stability windows are shortened, unlike the separate lap check.
Tracked runtime sources stayed unchanged throughout the run. The test-only
offscreen harness was committed during the run without changing its content.

After clearing graphics caches and five seconds of settling, static tracked
memory remains 441295516 bytes, with 183 resources. This is not RSS, GPU memory
or proof of safe iPhone memory use. Residual resource attribution remains open.

Rendered offscreen QA originally failed because asynchronous scene preparation
had not finished after its fixed 20-frame delay. The harness now waits for the
requested, non-busy screen with a 30-second deadline and awaits menu transitions.
Audio shutdown and drain remove its reproduced four-reference exit warning.
`/tmp/kras-platform-offscreen.log` ends with zero failures and passes the runtime
log guard. Four macOS Mobile renderer cases cover 1280x720 and 540x960 with one
and four touch regions. Portrait-four and landscape-one screenshots were
visually inspected: nonblank world, visible cues, controls and score chips.
Players are deliberately placed outside the camera in this fixture; it is not
a normal gameplay screenshot, a physical-device touch test or a FPS benchmark.

## Network and release boundaries

Two automated humans plus two bots: actual Godot peers and a temporary local
WebSocket service pass movement, host/client reconnect and result agreement
on seed 438683058. Scores `[4, 8, 14, 14]`, client 829 world snapshots,
observed server-loop maximum 23 ms. Evidence:
`/tmp/kras-platform-bot-peer.log`, exit 0, log guard pass.
This is not Internet or physical-user gameplay. Four-peer qualification also
passes: scores `[4, 8, 12, 16]`, clients 681/700/700 world snapshots, all peers
move, host and one client reconnect, server-loop maximum 42 ms. Evidence:
`/tmp/kras-platform-four-peer.log`, exit 0, log guard pass.

## Within-decision observation reuse

The connected selector initially rechecked visibility for every candidate's
neighbours. A new bounded-observation assertion failed on that implementation.
The selector now observes tiles once per decision, then uses their grid keys
for eight-neighbour scoring and cardinal routing. The visibility map is local
to that decision, never shared across time; warning cells remain traversable
but do not improve the solid-neighbour score. The direct neighbour API still
performs fresh visibility checks when no decision snapshot is supplied.
The focused suite now passes ten assertions, including proof that newly hidden
tiles do not survive into the next decision. The complete focused perception
suite still passes 2085 assertions.

The repeated natural offset-600000 sample is identical in baseline wins,
duration, character/slot bias, difficulty completion and Expert share to the
routing-only sample. Source and report:
`/tmp/kras-platform-optimized-balance-report/report.json`, exit 0, log guard pass.
At independent offset 900000, all 24 baseline and 16 difficulty rounds complete:
mean 6.331944 seconds, slot and character bias 0.125, Expert share 0.6625,
zero ties and no report flags. Both stress checks pass. Evidence:
`/tmp/kras-platform-optimized-independent-report/report.json`. The duration
issue remains; no balance threshold was relaxed to hide it.

The final full pipeline on 6527fc4 exits 0:
`/tmp/kras-platform-optimized-full.log`, artifacts
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.vHY2fV`.
384 scripts, 424 resources, 21 autoloads, 27 routes, eight characters,
zero inventory issues; 360630 unit/integration assertions pass in 330.9 seconds.
The separate three-lap race, six boss regressions and 39-match stability pass.
Settled static memory after graphics-cache release: 441297548 bytes.
These counts replace, not add to, the preceding full-run counts.

Final two-human/two-bot peers pass on seed 438683058: scores `[4, 8, 14, 14]`,
829 client world snapshots, host/client reconnect, maximum loop 39 ms.
Final four-human peers pass: scores `[4, 8, 12, 16]`, clients 680/700/700 worlds,
host/client reconnect, maximum loop 36 ms. Evidence:
`/tmp/kras-platform-optimized-bot-peer.log` and
`/tmp/kras-platform-optimized-four-peer.log`, both exit 0 and log guards pass.
Automated local peers and concurrent host timings are not device/Internet QA.

The existing isolated font probe on the parent source measures 33557590 bytes
at baseline, 59879686 with labels alive, 59438950 after their removal, and
40314314 after dropping shared font references. After the final runtime's
39-game lifecycle, the existing `--profile-idle-ui` diagnostic drops static
memory only from 441296892 to 424434096 bytes. All 39 lifecycle checks pass.
Thus shared UI font references do not account for the full residual memory.
Logs: `/tmp/kras-current-font-memory.log`, `/tmp/kras-platform-idle-ui.log`.
No runtime font-cache policy or graphics downgrade was introduced.

## Parent CI and production evidence

GitHub run 37380852853's core artifact explicitly records checkout commit
`cb692323bd44214dde54a74a036078e1a457300e`, tree
`e2bb24e3116f21995e07037368f6e08315f9d1a7`, push/main, no tracked changes.
That tree matches the local release commit. The downloaded artifact proves
360621 Godot assertions, 192 server tests with zero skips, and 117 stability
matches with zero failures on Linux. It does not qualify this unmerged branch
or establish completion of the still-running network matrix.
Artifact: `/tmp/kras-ci-cb69232-core`; receipt: `_temp/kras-qa-source.json`.

The parent source was deployed automatically to Railway production:
deployment `e4abeab8-1992-49c0-8277-75948d57e732`, SUCCESS, main, full hash above.
Fresh health returns ok/authentication_ready true and multiplayer_enabled false.
Six deployment-start log entries contain no reported errors. This branch is
not deployed. Fresh read-only production SQLite quick_check and foreign-key
checks pass after that deployment; no player rows were read or changed.
Log: `/tmp/kras-production-cb69232-db-check.log`. The CLI's deprecated Config
as Code warning remains; no automatic infrastructure migration was applied.
No production online enablement, physical iOS qualification,
Distribution Archive, Apple upload, processing or review submission occurred.
