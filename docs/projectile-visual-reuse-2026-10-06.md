# Pooled projectile visual reuse - 2026-10-06

Parent: `482f04d7ba7ae342cc5c8928d8063fe0db544096`.

## Verified waste and change

Every `Projectile.configure` previously queued the three-node visual hierarchy
for deletion and created a replacement even when the projectile itself came
from the object pool. The visual root, core and tail are now built on first use
and retained across reuse; subsequent configuration replaces material references
using the existing material cache. Core/tail geometry, positions, emission,
color adaptation, collision, hit logic, guidance, sticky/ricochet behavior,
pool lifecycle and network protocol are unchanged.

## Regression evidence

The new real-node test cycles one projectile through release/acquire and
alternating colors 64 times, awaiting frames between configurations. Before
the fix, three identity assertions fail (318 pass / 3 fail), proving the test
detects the old behavior. After the fix, all 321 systems assertions pass,
including root/core/tail identity, exact mesh reuse, material/emission updates,
placement and absence of duplicate children. Output:
`/tmp/kras-projectile-reuse-red.stdout` and
`/tmp/kras-projectile-reuse-green.stdout`; the green strict test guard passes.

## Real-rendered comparison

Serial four-Bot Tank Arena probes, Metal Mobile on the same M5, 1920x1080,
scale 1.0, actual engine FPS cap 0 and requested VSync 0, isolated saves and
identical seed/configuration. Both complete ten live seconds and the sample
budget; four competitors move and nodes return to the initial 51.

| Measurement | Before | After |
| --- | ---: | ---: |
| Samples | 493 | 522 |
| Mean frame ms | 18.30 | 17.25 |
| p95 frame ms | 28.73 | 22.02 |
| Worst frame ms | 88.76 | 80.19 |

Logs: `/tmp/kras-projectile-live-before.stdout` and
`/tmp/kras-projectile-live-after.stdout`. Strict runtime guards pass.
This is one serial pair on a shared development Mac, not a statistically
controlled performance guarantee or an exclusive CPU/GPU profile. In
particular the mean remains above 16.67 ms and stalls remain. The direct
allocation-reuse regression is the strong mechanism evidence; the observed
frame change is not proof that every difference is caused by this edit.

## Release limits

No visual quality was lowered or gameplay feature removed. No actual iPhone
performance, heat, battery, long-duration soak or Internet acceptance is claimed.
Fresh Xcode 27 device inventory still reports the physical iPhone unavailable:
`/tmp/kras-current-physical-devices.json`. No main merge, Railway deploy,
archive, Apple upload or review submission was performed.

## Full regression gate

`tools/check_party.sh` completed with exit 0: all 395 scripts compile, inventory
audits 447 resources / 22 autoloads / 27 routes / 8 characters with zero issues,
366,511 assertions pass, race regression and all six boss checks pass, and one
full stability cycle completes 39 matches with zero failures. Every strict log
guard passes. A single stability cycle is not a long-duration leak soak.
Main output: `/tmp/kras-projectile-reuse-full-gate.stdout`; detailed evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.38WgeR`.
