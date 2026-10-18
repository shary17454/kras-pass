# Sweeper Contact Diagnostics

Parent: `458e967b9b4fa32ecdf8bb181d4f25a15945d617`.
Branch: `feature/kras-online-random-rotation`.
No character, hazard, AI, physics or scoring values were changed.

## Development Tool

`tools/balance_contact_probe.tscn` reuses the natural balance runner and records
existing EventBus.player_hit feedback into the isolated test-storage file
`contact-probe.jsonl`. Each row records seed, character IDs, AI difficulty,
rules, completion, scores, accepted environmental/player push and blocked
zero-push feedback. It records no names, account identifiers or user saves and
does not transmit telemetry. Counts are bounded per player; the file streams
one row per completed attempt. The callback is disconnected after each match
and on teardown. Invalid slots/nonfinite push are counted as invalid evidence.

Example:

```sh
godot --headless --fixed-fps 60 --path . tools/balance_contact_probe.tscn -- \
  --only=sweeper_storm --runs=24 --seed-offset=3400000 \
  --out-dir=/tmp/kras-sweeper-contact-report \
  --test-data-dir=/tmp/kras-sweeper-contact-save
```

## Qualification

- Eleven attribution, invalid-event, reset and stale-feedback assertions pass;
  strict runtime log passes: `/tmp/kras-contact-probe-unit.log`.
- All 429 scripts compile; strict log passes:
  `/tmp/kras-contact-probe-compile.log`.
- Natural observed sample: 24 baseline, 16 matched difficulty, two smoke
  matches, all completed; 42 valid diagnostic rows, zero invalid contacts.
  `/tmp/kras-sweeper-contact-24.stdout` passes the strict runtime guard.
- Control run: same source, seeds and rules through the uninstrumented runner,
  all 42 matches completed. The entire reports match after removing only their
  generated timestamps, including outcomes, durations and difficulty samples.
  This is evidence of noninterference for this sample, not all future games.
- Both reports have matching start/end fingerprints:
  `4e8d1c4a5114456f373894eea8f1f53c996256342219b5fae6da7d0637bdb5b1`.
- Checked-in observations/control reports and JSONL are under
  `docs/qa/sweeper-contact-2026-10-08`.

## Findings And Limits

Each character appeared in 12 baseline matches. Sakhra won eight, while Nabta
and Ghaim won one each. The small sample has no automatic balance flag but
does not invalidate the earlier independent 96-match character warning.

Environmental contacts greatly outnumbered rival contacts for all characters:
Sakhra received 251 environmental and five rival hits; Nabta 106 and five;
Ghaim 148 and three. This narrows investigation away from simply blaming
idle brawling. Raw totals are confounded by survival time: a winner remains
exposed longer, so these numbers do not prove that resistance, jumps or a
specific collision defect caused the wins. No speculative gameplay fix was
applied and no balance threshold was weakened.

Source-wide balance qualification, the retained larger warning, actual device
playability/performance, production rollout and signed local Xcode release
remain open. This development diagnostic is not an Archive, upload, processing
or review submission. Mac lock still prevents browser/native UI inspection.
