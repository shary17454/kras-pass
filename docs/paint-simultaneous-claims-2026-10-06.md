# Simultaneous Paint Claim Qualification

Runtime commit: `baeea4914be634de675d0f1b7ddb828e67c2eac1`, based on
`55160ae7817a0bb9d998529f3debcac7dd81205c`. This feature branch is not main,
production, a signed iOS Archive or an App Store submission.

## Reproduction and Change

The previous Paint Grid loop immediately applied claims in fighter-array order.
Four symmetric grounded dash crosses claiming the same centre tile therefore
gave slot 4 ownership on all 16 ticks. The corrected real-floor fixture passed
55 assertions and failed four before the implementation changed. An initial
fixture started too high to land in its allotted frames; its floor failures
are test-authoring evidence, not evidence of the paint bug.

The controller now collects claims before resolving ownership once per tile.
Closest horizontal tile-centre contact wins. Exact proximity ties use rotating
priority, initialized from the existing match seed and round index. It does
not consume shared gameplay RNG or give a permanent slot-number advantage.
The existing single-player painting, dash cross, underfoot sound and variant
hooks remain. Round start clears pending claims and resets recount/priority.
Mnatiq and Mukharrib inherit the same controller; no player logic was copied.

The expanded real-floor test passed 69 assertions, including all four slots,
closer walking contact outranking distant dash crosses, deterministic round
reset and restoration of original fixture collision masks. Paint network
ownership/colour/score contracts passed 722 assertions. Both strict log guards
passed. Focused logs use `/tmp/kras-paint-contention-*` and
`/tmp/kras-paint-claims-network-suite.*`.

## Full Current-Source Gate

`tools/check_party.sh` completed with exit zero while runtime source was
unchanged, using Godot 4.7.1 and isolated saves:

- 394 scripts compile.
- 439 resources, 22 autoloads, 27 routes, eight characters, zero inventory issues.
- 366360 assertions pass in 325.5 seconds.
- Race regression and six boss probes pass.
- 39 stability matches, zero failures; every strict stage log guard passes.
- Main stdout: `/tmp/kras-paint-claims-full-gate.stdout`.
- Detailed evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.1WGGZK`.

The six actual Godot world captures from that run were supplied to server
`npm test`: 193 passed, zero failed and zero skipped. Log:
`/tmp/kras-paint-claims-server-fixtures.stdout`.

## Natural Matched Comparisons

Four reports completed 24 baseline, 16 mirrored matched-seed/character
difficulty and two mutator/chaos rounds each: 168 matches. The natural ordinary
80-second round window and balance policy were unchanged. All reports passed
strict runtime guards, mutator checks and start/end source fingerprint equality.

| Seed offset | Before slot bias | After slot bias | Before Expert rank share | After Expert rank share |
| --- | ---: | ---: | ---: | ---: |
| 1500000 | 0.208333333333333 | 0.150000000000000 | 0.687500000000000 | 0.683229813664596 |
| 1800000 | 0.208333333333333 | 0.083333333333333 | 0.687500000000000 | 0.677018633540373 |

All four reports have empty flags. The original Linux campaign's slot warning
did not reproduce in the macOS baseline, so do not claim a same-platform
warning was removed. The exact last-writer defect is proved by the grounded
reproduction; the limited natural cohorts support reduced observed slot bias,
not population confidence or a READY promotion. Expert rank share declined
slightly in both cohorts and is not a win rate. The first after cohort includes
a tied baseline result, so its per-slot win totals can exceed 24.

Baseline checkout: `45340110464e762be05f8d362474bdbbfd86f44c`, clean before and
after. Its shared runtime differs from the parent only in unrelated Blast Ball
AI; the paint runtime is unchanged. Baseline fingerprint:
`2d3e970ae4f962679d4025f9ed32ce0fa693b870492f16e9e0b4c61aa51a4072`.
After fingerprint:
`e76a1f1a5a29ed5a5465c4138b0bc1b78dfb4ca372d3ecb35cf8c71e6045a16f`.
Reports: `/tmp/kras-paint-claims-{before,after}{,-independent}-report/report.json`.

## Real Local Network

Separate Godot processes plus the actual local WebSocket server passed both
Paint Grid cases at seed 1504242 with exit zero:

- Two human input processes plus two bots agree on `[17,21,124,111]`.
- Four human input processes agree on `[15,27,21,23]`.
- Movement and designated host/guest reconnect pass; the two additional peers
  are not designated reconnect subjects.
- Guest world counts are 1088/1107. Server loop maxima are 39/57 ms under
  concurrent testing, not a physical FPS or Internet latency acceptance result.
- Log: `/tmp/kras-paint-claims-network.stdout`.

Automated processes do not prove four real humans on touchscreens/gamepads,
Internet connections, rendered portrait/landscape layouts or phone thermals.

## Open Release Gates

The completed old-source campaign has six flagged games and cannot qualify
this newer runtime. Wider balance/AI perception review, current-source immutable
network qualification, physical-device human QA/performance/battery, coordinated
production protocol rollout, final integration/version/build, and exact-source
signed local Xcode 27 Archive/upload/processing/App Review remain open. The
previous attested iOS build predates this change and must not be reused as proof
that it includes this paint fix. No main merge, production change or Apple
submission was performed.
