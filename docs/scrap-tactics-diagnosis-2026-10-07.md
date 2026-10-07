# Scrap Karts tactical diagnosis

Runtime/reference report: `d5524b9c95f7122b598932ff1f84a07d19c26fb5`.
Branch: `fix/kras-scrap-tactics-diagnosis`. The only new executable files are a
development trace scene/script. Production gameplay, AI profiles, perception,
physics, characters, random draws, balance policy and thresholds are unchanged.

## Method and verification

`tools/scrap_tactics_trace.tscn` requires isolated save storage. It reuses
balance_sim's actual paired configuration and tick-budget methods, not a
separate abbreviated match. It reads controller health/wrecks, fighter motion
and driver maneuver state after physics frames. No targeting/decision helper
or RNG method is called by telemetry. Reference seed offset: 1200000.

Sixteen natural Expert/Easy comparison matches completed, including all eight
matched character/seed pairs. An independent Node assertion pass verified
sample index, seed, character, scores, places and natural completion against
the preceding balance report. All sixteen results are identical. Exit zero
and strict log check passed: `/tmp/kras-scrap-tactics-trace-final.log`.
An invalid seed-offset test exited 2 with the expected rejection before any
match or trace row: `/tmp/kras-scrap-tactics-invalid.log`.
Godot resource import exited zero and passed its log guard:
`/tmp/kras-scrap-trace-import.log`. It recreated missing UID metadata for the
existing driver-engagement and vehicle-dash test scripts; those warnings are
retained and their unrelated generated metadata is not part of this change.

An earlier trace omitted eliminations on the ending frame because it skipped
non-PLAYING phases. Its survival/death counts in
`/tmp/kras-scrap-tactics-trace.log` are superseded, not accepted as evidence.
The corrected trace reads final controller state before teardown. Alive/state
tick counters exclude the ending transition; they are not exact event timing.

## Observations, not a balance fix

| Tier | Participations | Ram eliminations | Falls | Survivors | Alive ticks | Backoff ticks | Edge ticks | Dash ticks |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Easy | 32 | 25 | 0 | 7 | 46219 | 4705 | 8941 | 474 |
| Expert | 32 | 25 | 0 | 7 | 42238 | 14775 | 6605 | 1841 |

In this cohort the difficulty deficit is not explained by falling off the
arena. Equal elimination counts do not imply equal finishing places: Expert
has fewer total alive ticks and substantially more backoff/dash exposure.
Backoff occupies about 35.0% versus 10.2% of observed alive ticks. This is a
tactical hypothesis, not proof that backoff or dash causes worse results.
Ram deaths are classified by the actual wreck counter; health loss alone would
not distinguish ram damage from on-fall health clearing. Some rounds end with
simultaneous wrecks; their existing rankings are preserved.

The current natural report's Expert share remains 0.49375 and retains its
balance warning. This development measurement does not fix it or qualify the
game READY. A candidate maneuver must receive a focused behavioral regression
and matched/held-out natural comparisons before adoption. Do not buff stats,
reduce acceptance thresholds or choose only favorable seeds.

Raw generated trace and aggregates:
`docs/qa/scrap-tactics-2026-10-07/trace.json`.

Reproduce:

```sh
godot --headless --fixed-fps 60 --path . tools/scrap_tactics_trace.tscn \
  --log-file /tmp/kras-scrap-trace.log -- --seed-offset=1200000 \
  --test-data-dir=/tmp/kras-scrap-trace-save
```

No main merge, production database action, Railway deployment, phone install,
archive, upload or Apple submission. Campaign 37670303689 remains on d5524b9;
the trace branch is not substituted as that campaign's checkout.
