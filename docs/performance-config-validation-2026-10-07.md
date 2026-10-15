# Performance Evidence Configuration

Base: 8a393da147c90eb0738440ffa25fa23dbfe580b0.
Scope: tests/soak_perf.gd and its sampling regression suite only.
No gameplay, shipping quality, network, save or signing settings changed.

## Confirmed Gap

The probe accepted nonexistent arena dune_ruins for tank_arena. MatchScene
used its production fallback, but the report retained the requested invalid
name. That earlier report is excluded from release qualification.

The probe now refuses unknown games, unknown or incompatible arenas,
nonfinite/nonpositive durations, negative frame caps and invalid quality
tiers before construction. Empty arena remains a supported default choice.
Headless runs cannot emit rendered performance evidence. After setup, the
actual ArenaDef ID must equal MatchConfig's resolved ID; built_arena is
recorded alongside arena.

## Tests

- Red: 23 assertions passed and 10 failed with the unvalidated helper.
- Green: all 33 sampling assertions passed.
- All 396 scripts compiled; git diff --check passed.
- Unknown arena CLI: exit 1 and no JSON report emitted.
- Headless valid-config CLI: exit 1 and no JSON report emitted.
- Actual Metal mobile-renderer tank_oasis window run completed an 8-second
  live window with the requested 5-second steady sample; built_arena and
  arena both equal tank_oasis.
- Logs/reports: /tmp/kras-perf-config-{red,green,compile}.log,
  /tmp/kras-perf-config-{invalid-cli,headless-cli}.log,
  /tmp/kras-perf-config-valid-render.{log,json} and
  /tmp/kras-perf-config-valid-verbose.{log,json}.

The first short rendered run printed an exit warning for two ObjectDB
instances and one resource. The verbose rerun did not reproduce it. It is
retained as unresolved, not described as fixed or a clean shutdown. Engine
log files may omit late shutdown output; preserve stdout too when qualifying
absence of exit warnings. The verbose run itself had one 51.581ms steady
frame, so it is not evidence of universally hitch-free performance.

## Resolution Interpretation Correction

Previous reports recorded ViewportTexture.get_size() as 484x1049 or700x323,
while the captured image dimensions were590x1280 or1280x590 and 3D scale1.0.
That difference alone does NOT prove reduced internal 3D resolution.
Godot's upstream ViewportTexture getter applies the viewport stretch scale
for root windows, whereas get_image reads the render-server texture.
Reference: https://raw.githubusercontent.com/godotengine/godot/master/scene/main/viewport.cpp.
This source reference explains the possible metric mismatch; it is not an
attestation of this local binary's exact engine source or GPU target size.

## Remaining Release Gates

No new all-game performance certification, phone/iPad QA, physical energy or
thermal measurement, long leak soak, main merge, Railway deployment,
Distribution archive, upload or Apple review submission occurred here.
The parent's existing full gameplay gate remains separate evidence.
