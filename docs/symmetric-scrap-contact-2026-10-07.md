# Symmetric Scrap Karts Contact Qualification

## Scope

Base source: `d1a5a31f1d6af113e7c91dcdfa45acc68f2d41a9`.
Branch: `fix/kras-symmetric-ram-contact`.
Godot: 4.7.1-stable official a13da4feb, macOS.

The current Linux balance campaign 37526080082 reported Scrap Karts slot wins
13/3/2/6 over 24 natural baseline rounds. That warning prompted contact review,
but does not by itself identify a particular cause.

## Confirmed Bug and Change

Equal opposing approach velocities used the strict comparison's else branch,
assigning primary damage to the lower-numbered player and backwash to the other.
With closing speed 20, the original health results were approximately 69.14 and
89.71 despite identical head-on approaches. The new equal-approach branch shares
the existing primary/backwash damage budget. Directional flank multipliers are
still computed separately for each victim. Unequal approaches keep the original
attacker, primary damage and backwash rules.

No changes to character stats, thresholds, seeds, AI, spawn points, networking
schema or release numbers. Multi-contact processing and simultaneous elimination
ordering are not changed by this patch.

## Verification

- Focused regression before gameplay change: 93 passed, 12 failed.
- Focused regression after change: 121 assertions passed.
- Coverage includes four different player pairs, mirrored world directions,
  vertical velocity exclusion, unequal attacker slots, cooldowns, round reset,
  network serialization validation and guest presentation without authority.
- Shared scoring/tournament tests: 47 assertions passed.
- Godot log guards and git diff whitespace check passed.

Evidence logs:

`/tmp/kras-ram-red-corrected.log`

`/tmp/kras-ram-green.log`

`/tmp/kras-ram-scoring.log`

## Natural Balance Follow-Up

`/tmp/kras-ram-balance-report/report.json` and `/tmp/kras-ram-balance.log`:

- 24 natural baseline rounds completed.
- 16 mirrored same-seed/same-character difficulty matches completed.
- 2 mutator stress matches passed.
- Seed offset 300000, not clipped rounds.
- Slot wins remain 13/3/2/6, slot bias 0.2916667.
- Expert placement share remains 0.5217391.
- Warning remains: `spawn slot advantage`.

This sample does NOT establish a balance improvement. It independently proves
the unfair equal-contact rule is fixed while preserving the unresolved warning.
Linux/macOS samples are not a controlled platform comparison. Full-suite, physical
iPhone performance, current-source network peers and independent larger balance
qualification remain required before release. This branch is not merged into
main, not deployed to Railway, and not submitted to App Store Connect.
