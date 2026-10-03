# Colossus impact lifetime checkpoint

## Actual peers before these fixes

The two-peer test at seed 9614 still failed after the target-height fix:
`kras-network-smoke-1qA8rA` under the current macOS temporary directory.
Round zero expired with boss health 85. Diagnostics showed players hundreds of
metres away and above the ring. This is not online qualification.

## Shrinking arena ejection

`MatchScene._check_out_of_bounds()` used to add a four-unit impulse on every
physics frame outside a shrinking arena. The regression measured 484 units after
121 checks, rather than a single four-unit exit cue.

Ejection is now one cue per exit. Returning inside or leaving active play rearms
it, and a new round clears it. Its direction uses the arena-relative position.

Evidence: `/tmp/kras-shrink-ejection-before.log` (one failure),
`/tmp/kras-shrink-ejection-after.log` (four assertions passed).
Compilation at this checkpoint: `/tmp/kras-shrink-compile.log`, 318 scripts.

The subsequent actual two-peer run, `kras-network-smoke-H97Xl6`, defeated
Colossus in round zero and entered round one, but exceeded the existing 450-second
deadline. It is FAILED, not a complete match or tournament qualification. No
deadline, boss health, damage or exposure window was changed. Upward launches
were still observed, so the ejection fix alone does not resolve all physics bugs.
Preparation frame gap reached 32139 ms. The host machine reported load averages
above 500, and later failed to spawn processes with `Resource temporarily
unavailable`. These timings cannot establish a device performance baseline.

## Stale fighter contacts

`Fighter.resolve_impacts()` retained its pair queue across physics ticks, so a
contact could apply another hit after its cooldown even when the bodies had
separated. Contact collection also refused to replace an existing pair's normal.
The queue now drains after every resolution; cooldowns remain independent.

`/tmp/kras-ram-contact-before.log` proves the old remote pair delivered another
5.3427 units and remained queued (two failed assertions).
`/tmp/kras-ram-contact-after.log` passes all four assertions, including a
legitimate first hit, no subsequent stale hit, and a drained pair queue.
Final compile evidence: `/tmp/kras-impact-final-compile.log`, all 319 scripts
compile. Godot also emitted a macOS system-CA lookup warning; this is not proof
that production TLS or authentication is healthy.

Full post-contact-fix two/four-peer games, tournament/final/reconnect qualification,
physical-device performance and release gates remain pending. No Railway or
App Store deployment was performed at this checkpoint.

## Follow-up peer run and respawn spacing

The post-contact-fix two-peer seed 9614 run, `kras-network-smoke-HT2Y0t`,
failed round zero with health 140. Two returning fighters shared exactly the
same position and were later launched upwards; this remains a failing test.
Source inspection found that the Colossus respawn search tried the center first
without checking active bodies. This is a demonstrated overlap bug, not proof
that overlap alone explains every vertical launch.

The new spacing regression failed seven assertions before the fix. It now
passes twelve assertions: every sequential returning player has real ground and
capsule clearance. The search checks the preferred spawn as well as alternate
points, uses the fighters' actual capsule radii, and repeats those checks after
the existing exhausted-ground recovery. Logs:
`/tmp/kras-colossus-respawn-before.log` and
`/tmp/kras-colossus-respawn-after.log`.

The existing approach regression now expects a selected player's horizontal
coordinates on the arena floor, matching the target-height fix rather than the
old jumping height. Eligibility assertions remain unchanged.
`/tmp/kras-impact-spacing-approach.log` passes all 89 assertions;
`/tmp/kras-impact-spacing-compile.log` compiles all 320 scripts.

Git publication uses an independent temporary clone because the source
worktree's original Git pack index is an iCloud dataless file. The pending local
commit was interrupted without deleting its staged work or another process's
locks. This does not qualify a production build or allow release gates to be
skipped.
