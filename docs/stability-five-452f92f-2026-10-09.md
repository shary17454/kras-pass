# Five-cycle stability qualification - 2026-10-09

## Source and scope

- Checkout: `04ce74662078406e6d26bb93146de67750bdaae6`, branch `feature/kras-online-random-rotation`.
- Runtime source matches archive source `452f92f84e30f7b26bfebc92b2598f124316a56f`.
- Runtime fingerprint after testing: `274d1649bf08d310aab79374014795d542e687e47d2680975398598187ad1774`.
- Godot 4.7.1, headless, fixed simulation rate 60, four AI players, 39 default arenas, five cycles.
- Timed rounds use five-second overrides; race lap requirements are unchanged. Save writes and replay recording are disabled by this harness.
- No runtime source or test files were changed during these runs.

## Results

- Compilation: all 444 scripts compile, isolated rerun exit 0.
- Stability: 195 matches, zero reported failures, exit 0. Independent JSON audit verifies all 39 games occur once in each of five cycles.
- The harness checks natural completion, valid ranking and finite player state, released match weak references, restored scene/node/orphan counts, signal connections and input sources.
- Post-warmup memory growth: 1,016,552 bytes, below the harness threshold of 16 MiB. This is Godot static allocation telemetry, not physical-device resident memory or proof that no leak exists.
- After simulated OS memory warning and settling, material, mesh and texture caches each contain zero entries.
- Both isolated compilation and stability stdout/engine logs pass the repository runtime log checker.

## Preserved diagnostics and limitations

- The initial compile run had no explicit test directory and reported inaccessible `user://test-runs` directories. Its exit 0 and compile summary are not accepted as a clean run; the isolated rerun eliminates those storage errors.
- Both qualifying runs still log the macOS engine CA-certificate diagnostic `Condition "ret != noErr"` in `get_system_ca_certificates`. The runtime checker does not reject this platform diagnostic. These are not error-free logs or HTTPS/certificate qualification.
- The stability memory-warning log is deliberately triggered by the harness.
- No all-map coverage, physical four-human session, full-length balance, production networking, controller hardware, device FPS, thermal or battery acceptance is established here.
- Stage-zero acceptance remains pending; these results do not classify all games READY, authorize production deployment, or constitute Apple submission.

## Evidence

Raw JSON and all first-attempt/qualifying logs are preserved outside the tracked repository in `../qualification-stability-five-452f92f-2026-10-09/`.

Commands:

```sh
godot --headless --path . --log-file /tmp/kras-452-compile-isolated.log tests/compile_check.tscn -- --test-data-dir=/tmp/kras-452-compile-isolated
godot --headless --fixed-fps 60 --path . --log-file /tmp/kras-452-stability-five.log tests/stage_zero_stability.tscn -- --cycles=5 --test-data-dir=/tmp/kras-452-stability-five
```
