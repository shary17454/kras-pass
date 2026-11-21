# Partial independent balance review

This is a two-game checkpoint, not a complete 39-game campaign.

Campaign `37813002835` remained live at inspection. Tested commit:
`78d11abdb35144a6c754414487606093dd5c1435`.
Fingerprint `b90edfc4d8fb5f0b42fa8063f41e564f252a0c9f40ea09e2f3e2db1fa990d553`.
Seed offset `4200000`; official Godot 4.7.1.

Downloaded Blast Ball and Scrap Karts artifacts. Independently regenerated
`tools/balance-report.mjs` summary with partial mode, paired policy and exact
commit, run, engine, seed offset and source fingerprint. The verifier checks
each available game's mirrored seeds/characters and both exchanged expert
cohorts even though campaign-level consistency/pairing booleans remain false
while games are missing. All six import/policy/simulation log guards passed.

| Game | Natural baseline | Paired difficulty | Stress | Expert score share | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| blast_ball | 24 | 16 | 2 | 0.48125 | expert bots no better than easy |
| scrap_karts | 24 | 16 | 2 | 0.5375 | none |

Both reports contain 42 completed matches. Their starting and ending source
fingerprints match. No timeout restart, threshold change or force-completion
was used. Complete reports are retained under
`qa/partial-4200000-2026-10-08/`; the externally downloaded artifacts and logs
are in `../qualification-4200000-partial/` relative to the repository parent.

The Blast Ball physical contact travel-budget repair does not establish a
difficulty-balance fix. Its warning persists in this independent cohort.
Scrap Karts has no warning in this cohort but historical warnings remain;
this result does not justify declaring universal balance or release readiness.

The later HUD recovery-marker runtime change at `946eb17` is NOT included in
these reports. Neither these partial artifacts nor successful workflow jobs
prove final-source qualification, iPhone performance, production integration,
archive signing, upload or App Review submission.
