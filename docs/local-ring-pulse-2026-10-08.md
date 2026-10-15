# Local identity ring pulse repair

## Defect and change

`Fighter.mark_as_local()` sets the ground-ring scale to 1.18, but
`_update_markers()` previously replaced that scale with a unit-base pulse on
the next frame. Local players lost their intended persistent enlargement.
The pulse now multiplies the existing 1.18 local base size. Bot ring size,
vertical thickness, body scale, collision dimensions, movement and AI logic
are unchanged. This preserves an existing visual design rather than adding
a local-player gameplay advantage.

## Tests

- RED systems suite: 748 assertions passed, eight failed. All failures were
  local ring X/Z scale checks at four pulse phases.
- GREEN systems suite: 756 assertions passed, exit 0. The new checks cover
  local/non-local rings, both floor axes, unchanged thickness and body scale.
- Complete suite: 392655 assertions passed, exit 0, 176.2 seconds.
- Compile check: all 430 scripts, exit 0.
- Metal visual smoke: four human touch slots, Goal Guard and Colossus,
  portrait and landscape; four captures, zero automated failures. Colossus
  portrait was inspected manually; actors remain small and need further polish.
- Strict compile, systems, full-suite and visual log guards passed.
- `git diff --check`: passed.

Logs/screenshots: `../qualification-local-ring-2026-10-08/` relative to the
repository parent. Full log SHA256:
`8b4d20152a2488f8c767d8736dad14d6c10ec3145d21d112d3bab92dea43fb4c`.

## Blast Ball diagnosis before this repair

Before changing the fighter visual, ran the existing non-mutating contact probe
on the tracked source at `bf9181f` with seed offset 4200000. All 42 matches
completed, zero invalid contact events and strict runtime-log guard passed.
The simulation fingerprint stayed
`5e010dfebaa8b6c893c453e07bd42e3345f9e3eff242767e226a74d24656ad2b`.
Its report still flags `expert bots no better than easy` (expert share 0.475).

In 16 mirrored comparisons (32 slots per tier), Expert won 7 matches and Easy
9. Expert received 132 accepted environment pushes over 656.33 alive-seconds;
Easy 127 over 670.98 seconds. These events combine ball contacts and blast
pushes; they cannot establish the cause of the difficulty warning. No approach
path change, AI stat change, threshold relaxation or balance-pass claim was made.

The command used an unsupported `--out` option, which the existing runner
ignored; actual generated report was `build/balance/report.json`. Copied that
report, the contact JSONL and engine log to
`../qualification-blast-exposure-4200000/`. This diagnostic therefore does not
claim the requested scratch report path was used.

## Open release gates

The running GitHub campaigns target `78d11ab`, not this changed source.
No final-source 39-game campaign, device QA, production promotion, signed
archive, upload or App Review submission is proved here. The physical iPhone
and protected production/ASC access approvals remain separate pending gates.
