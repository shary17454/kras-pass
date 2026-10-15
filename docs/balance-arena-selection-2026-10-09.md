# Explicit arena qualification

## Change

The balance simulator now accepts `--only=GAME --arena=ARENA`. It rejects
empty, unknown, duplicate, and cross-game arena selections before changing
configuration. Every baseline, difficulty comparison, and mutator match uses
the selected arena. Results from an unexpected arena are rejected.

Reports retain `arena_override` and the game row's `arena_id`. The ordinary
default-arena campaign aggregator rejects targeted-arena evidence; a successful
alternative-map experiment cannot substitute for the existing campaign.

## Verified locally

- Godot 4.7.1: focused balance suite, 7643 assertions, exit 0.
- Node report consumer: 84 tests, 0 failures.
- Compile check: 445 scripts, exit 0.
- Strict Godot log checks passed for local focused tests, compile, and simulation.
- Woodland Valley (`tank_oasis`): 8 baseline + 16 mirrored difficulty + 2
  mutator matches completed using natural windows, no review flags in this sample.
- Simulation start/end source fingerprint:
  `f463ee19b68ef5d290d900792602250385802322e9e407ea92459b816f0b8913`.

The first sandbox test attempt crashed opening the default user log. A retry
with an explicit temporary log passed assertions but reported a system CA
access error. Neither attempt qualifies the clean local run; the system-session
run with isolated test storage passed without that error.

## Evidence

Retained outside the checkout in `../qualification-arena-selection-2026-10-09/`:
local test and compile logs, Node test output, natural-match stdout/log, and
JSON/HTML simulation reports. Simulation command:

```sh
godot --headless --fixed-fps 60 --path . --log-file /tmp/kras-oasis-arena-selector-natural.log tools/balance_sim.tscn -- --only=tank_arena --arena=tank_oasis --runs=8 --balanced-rosters --seed-offset=11500000 --out-dir=/tmp/kras-oasis-arena-selector-results --test-data-dir=/tmp/kras-oasis-arena-selector-save
```

## Limits

This adds verification coverage, not new Woodland Valley geometry. The small
sample does not certify final balance, all maps, device FPS, thermal/battery
behavior, production networking, or App Store readiness. Existing default-map
campaigns retain their original source and coverage. Production promotion and
Apple submission remain subject to the unresolved release gates.
