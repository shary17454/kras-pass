# Prebaked Original Sound Effects

## Change

Based on d1a5a31f1d6af113e7c91dcdfa45acc68f2d41a9 in an independent branch.
AudioManager previously synthesized every SFX and ambience on first request.
It now loads and caches 38 original one-shot resources and two looping ambience
resources (ATV engine and wind). The procedural generators remain the editable
source and fallback. No composition, pitch, bus, volume, alias, voice-pool limit
or gameplay rule was changed. No third-party game sounds were introduced.

tools/bake_original_sfx.gd/.tscn regenerate the binary AudioStreamWAV resources.
Godot import generated UIDs for the new tool and the existing music bake tool;
both are included to avoid a missing source UID. Disk allocation measured about
728 KiB for SFX and 304 KiB for ambience, including filesystem block rounding.

## Verification

- RED: 644 assertions passed, 80 failed before the runtime loader change.
  All 40 resources matched the original PCM; the failures were bundled/cache
  identity checks proving playback still synthesized instead of loading assets.
- GREEN: 724 assertions passed, strict test log guard passed. Every PCM byte,
  sample format, sample rate, channel layout and loop boundary matched Synth.
  Aliases share the same cached stream; unsupported ambience stays unsupported.
- Compilation: 396 scripts, all passed; strict compile log guard passed.
- Godot import and bake completed, with strict import/runtime guards passing.
- git diff --check passed.

An initial version of the bake tool had a GDScript inferred-type parse error for
the directory variable. Only its owned stuck process was terminated; the type
was made explicit and the tool was rerun successfully. This initial failed log
is not represented as a passing benchmark.

## Limited Desktop Operation Benchmark

Same Mac, headless Godot 4.7.1, empty audio banks, sequential first requests for
all sounds and ambience. No sleep or shortened gameplay rule was used.

| Source | Total first loads | Worst individual load |
| --- | ---: | ---: |
| Original runtime synthesis | 1001.469 ms | wind: 413.734 ms |
| Bundled resource loading | 17.025 ms | wind: 1.140 ms |

Logs: /tmp/kras-sfx-before-fixed.stdout and /tmp/kras-sfx-after.stdout.
These are one before/after desktop operation samples, not statistical FPS,
physical iPhone power/thermal evidence, or an entire scene-loading measurement.
The OS resource cache was not flushed. No claim of 60/120 FPS follows from this.

## Remaining Release Gates

The existing export configuration includes all resources and excludes tools and
tests, not audio assets. A new actual iOS PCK/archive must still verify these
resources, with full regression and physical audio acceptance before release.
No new Distribution archive, upload or review submission occurred here.

The active 39-game campaign remains pinned to d1a5a31; this branch does not
replace its source or cancel its jobs. It is not full qualification of this
new audio branch. No main merge or Railway deployment was performed.
