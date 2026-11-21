# Original music loading - 2026-10-06

Parent source: `test/kras-renderer-performance-evidence` commit `1961ef6`.

## Measured issue

Cold loading synthesizes original music synchronously before play. Metal Mobile
trace `/tmp/kras-metal-operations-before.stdout` measured three `audio.track_miss`
calls totaling 2,513,366 us (maximum 918,065 us). This is a preparation/scene-build
stall, not proof that music causes the later live-frame stalls.

## Change

Six original compositions are baked losslessly as AudioStreamWAV `.res` files.
`AudioManager._track` loads them and retains its existing cache; procedural
generation remains a development fallback. No composition, volume, loop,
controls, physics, AI, quality setting or character balancing was changed.
The additional resource bank occupies about 2 MiB on disk. The bake tool and
provenance are in `tools/bake_original_music.*` and `assets/audio/music/README.md`.

## Evidence

Systems suite: 311 assertions passed, including exact PCM comparison for all
six tracks, sample metadata, loop boundaries, resource identity/cache, unknown
track handling, independent music mute, shutdown and existing system behavior.
Output: `/tmp/kras-baked-music-tests.stdout`; strict test log guard passed.

Matched real-window Metal Mobile trace after change:
`/tmp/kras-metal-operations-after.stdout`. Three `audio.track_load` calls total
3,296 us, maximum 1,153 us; no music synthesis miss. Scene construction decreased
from 3,851 ms to 1,933 ms in these two observations. Resource preparation varied
from 2,203 to 2,491 ms. These are one serial pair, not statistical guarantees.

Both runs complete ten live seconds with four moving Bots and return to the
initial 51 nodes. Live presentation did NOT improve in the measured after run:
mean 16.89 to 17.55 ms, p95 17.76 to 27.17 ms, worst 72.46 to 75.41 ms. Frame
correlation and inclusive script-wall intervals are not exclusive CPU/GPU
profiles. This change closes the verified music-generation loading cost, not
the overall performance requirement. SFX generation and live-frame stalls
remain separate investigations. No iPhone heat/battery test, archive, upload,
Railway deploy, main merge or App Review submission is claimed here.

Full project gate subsequently completed with exit 0: 395 scripts compiled,
447 resources / 22 autoloads / 27 routes / 8 characters audited with zero issues,
366,501 assertions passed, race regression and all six boss checks passed,
and one full stability cycle of 39 games completed with zero failures. All
strict log guards passed. One cycle is not a long-duration memory-leak soak.
Main output: `/tmp/kras-baked-music-full-gate.stdout`.
Detailed logs: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.kU2UZJ`.
