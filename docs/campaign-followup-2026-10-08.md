# Campaign follow-up

Run `37694780646` at commit
`82f3a7692b8f61b341fb26d69b3170c3a82496cd` remains active. This is the source
BEFORE the subsequent Magnet first-contact fix, not a new full-source qualification
of that fix. Do not relabel its reports as current release evidence.

Downloaded and checked five additional reports. Each has 24 natural baseline,
16 matched-seed/character difficulty and two successful stress matches. Source,
checkout, run identity, seed offset 1200000, all seeds and coverage pass
`tools/balance-report.mjs --partial --paired --seed-offset=1200000`. Start/end
runtime fingerprints match `d0b4951682ded2f83058ab8a7d99f6558a527798d8d028b770efbcdcc4ca087e`.
Import, completed policy-test and simulation logs pass their existing guards.

| Game | Seat wins | Expert edge | Tie rate | Flags |
| --- | --- | --- | --- | --- |
| Turret Duel | 8,8,4,7 | 0.625731 | 0.125 | none |
| Scrap Karts | 4,10,5,5 | 0.50625 | 0 | expert bots no better than easy |
| Gem Grab | 5,6,10,7 | 0.632768 | 0.083333 | none |
| Star Rush | 5,6,4,9 | 0.691358 | 0 | none |
| Paint Grid | 5,6,8,5 | 0.6875 | 0 | none |

Seat wins can sum above 24 when a match has joint winners; ties are retained,
not silently resolved for the balance report. Aggregate validated coverage is
15/39 games and 630 matches; 24 reports are still missing from this snapshot.
Warnings remain in Crumble, Magnet (old runtime), and Scrap Karts.
No all-games READY or release-ready claim follows from these reports.

Raw new reports: `docs/qa/campaign-followup-2026-10-08/`.
All downloaded source and engine evidence:
`/tmp/kras-current-partial-campaign-37694780646/`.
Magnet's separate corrected-source reports and real-client checks are documented
in `docs/magnet-swept-contact-2026-10-08.md`. Scrap requires a causal AI review;
changing Easy/Expert parameters merely to clear this flag is not justified.
