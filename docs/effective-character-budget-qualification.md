# Effective character budget qualification

Runtime source: `8c1409ca9cc96f4844f2d1abb54eac4911c7cf0a`.
Parent: `0753d635b23b2393ae16626c6faa44c917f0b20e`, including the independently
qualified dodger jump-timing correction. This is a shared gameplay tuning
change, not only a Sweeper Storm adjustment.

## Actual stat constraint

Equal normalized stat totals did not keep actual fighter properties within
the requested 10-15 percent differences. The original runtime failed 15 of
64 effective-budget assertions, including acceleration, resistance, power,
turning and air control. The same fixture now passes all 64 assertions.

The five offending tuning axes now use a narrower base/range around their
unchanged neutral midpoint. Speed and jump were already inside the limit
including current perks, so their tuning is unchanged. Normalized roster
stats, unlocks, perks, characters and assets are unchanged. Combat damage,
hazard strength, round durations and AI difficulty are unchanged.

The fixture checks all eight characters' real Fighter values after perk
application, not only data JSON: speed, acceleration, jump velocity,
knockback resistance/power, turning and air control all stay within 15 percent
of a neutral character. It also asserts unchanged neutral values:
9.1 speed, 56 acceleration, 9.8 jump, 1.1 resistance, 1.08 power,
12.5 turn rate and 0.49 air control.
Power-ups and intentional mutators are not subject to this base-roster limit.
This arithmetic constraint does not prove equal win rates.

- `/tmp/kras-character-effective-red.log`: exit 1, 49 pass / 15 fail.
- `/tmp/kras-character-effective-green.log`: exit 0, 64 assertions.

## Natural Sweeper samples

Each sample uses 24 baseline rounds, 16 matched difficulty rounds and two
mutator/chaos checks. All durations, thresholds and seeds remain unchanged.
The comparison parent is the preceding jump-timing runtime, not older main.

At offset 600000, Expert score share changes from 0.56875 to 0.5875 and
character bias from 0.291667 to 0.25, still flagged. Wins: barq 1, ghaim 2,
mowja 4, ramla 1, sakhra 7, turs 9. Mean duration is 28.856944 seconds.

At independent offset 900000, Expert share changes from 0.56875 to 0.55625
and bias from 0.333333 to 0.208333; this sample has no report flags. Wins:
barq 1, fanoos 5, ghaim 1, mowja 2, ramla 3, sakhra 4, turs 8.
Mean duration is 24.934722 seconds. This is not a claim of complete balance:
turs still wins often and nabta did not win either sample. More natural
samples and cross-game comparison are still needed before READY status.

- `/tmp/kras-character-effective-balance-report/report.json`
- `/tmp/kras-character-effective-independent-report/report.json`
- Parent samples: `/tmp/kras-dodger-jump-balance-report/report.json`
  and `/tmp/kras-dodger-jump-independent-report/report.json`.

Both runs exit 0 and their runtime log guards pass. A zero exit does not
erase a review-level character-advantage flag.

## Shared regression and release boundary

Full project qualification completed on the exact committed runtime with
isolated saves, exit 0. Evidence:
`/tmp/kras-character-effective-full.log`, with artifacts under
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.l8NRc7`.
The unit/integration stage completed: 360621 assertions pass in 387.2
seconds. All 383 scripts compile; inventory finds 423 resources, 21 autoloads,
27 routes, eight characters and zero issues. The separate race regression
completes all four drivers' three real laps, exit 0. These are host/headless
checks, not device performance evidence. All six separate boss regression
checks pass. The stability stage completes one cycle through all 39 games
with zero failures. Ordinary stability round windows are shortened; the
separate lap finish regression is not. This does not prove the full QA matrix
of all games, player counts, orientations or sustained physical-device play.

After cache release and five seconds of settling, the engine reports
441286190 bytes of static memory and 183 resources. This is not process RSS,
GPU memory or proof of leak-free phone behavior; residual resource memory
still needs attribution and actual device measurement.

Two-human/two-bot networking on seed 438683058 exits 0 and passes the log
guard. Both actual Godot peers move and reconnect, agree on `[6, 6, 16, 14]`,
and the client receives 874 world snapshots. Observed maximum server-loop
interval is 69 ms during concurrent qualification. Evidence:
`/tmp/kras-character-effective-bot-peer.log`. Inputs are automated, not two
physical users or Internet/device gameplay.

The four-human automated peer run also exits 0 and passes the log guard:
scores `[6, 6, 14, 14]` agree, all peers move, the host and one client reconnect,
and clients receive 783, 802 and 802 world snapshots. Maximum server-loop
interval is 99 ms during concurrent qualification, not a device FPS result.
Evidence: `/tmp/kras-character-effective-four-peer.log`.

No physical iOS gameplay, sustained device FPS/battery/thermal measurement,
Distribution Archive, production-online activation or App Store submission
is established by this tuning change. Main-source GitHub Game Quality run
37370162621 remained queued when checked; no job was canceled or duplicated.
