# Modified-Source Regression Qualification

Tested commit: d1afb74c1352f91ac23a66176cd89f34f0e42b50.
Runtime fix: 3f1823af75b6a31eedddfc26ea8c630e729fc0dd.
Branch: fix/kras-blast-survival-margin; PR 178.
No source files changed while these processes ran. This document and the Star
Rush report are added afterward without further runtime changes.

## Current-Source Star Rush Retest

Retained failing campaign offset 1200000 was repeated naturally on this source:
24 baseline matches, 16 same-seed/same-character mirrored difficulty comparisons,
and two mutator/chaos matches completed. Process and strict log guard exited 0.
Expert score share 0.7, slot bias 0.0833333333333333,
character bias 0.208333333333333; report flags empty.

Source fingerprint before/after:
ba25854f89b88fb1b85f1324dfdcf2c5303471d4bb85cc506d614b5e3ca958e5.
Report: star-current-natural-1200000.json.
Raw log: /tmp/kras-star-current-1200000.log.

Nabta still won 8 of 24 baseline matches, with Barq winning 5; two characters
did not win in this sample. An empty statistical-warning list is not proof of
equal character strength or exhaustive balance. Preserve the older warning and
independent samples rather than describing this as universal balance acceptance.

## Complete Regression Gate

Godot 4.7.1-stable official. Full gate exit 0:

- 415 scripts compile.
- Inventory: 514 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- Main suite: 388519 assertions passed in 493.8 seconds.
- Separate Party Race regression passed.
- Six separate boss regressions passed.
- One stability cycle: 39 matches, zero failures.
- After cleanup/settling, cached textures/materials/meshes/audio returned to zero.
- All stage runtime log guards passed.
- Server tests using all six actual captures from this exact-source run:
  204 passed, zero failed/cancelled/skipped, exit 0.

Evidence: /tmp/kras-party-check.oEA8fq.
Gate log: /tmp/kras-blast-fixed-full-regression.log.
Server log: /tmp/kras-blast-fixed-server-captures.log.
The macOS system CA-access diagnostic remains. Save corruption, memory-pressure,
Replay-budget and transport failures are intentionally injected by fixtures.
One short cleanup cycle does not prove absence of long-session/device leaks.

## Remaining Gates

The two Blast Ball samples and this Star Rush retest do not qualify all 39 games
on the changed source. Broad natural balance, game-specific playability,
physical iPhone/iPad multiplayer/touch/orientation/gamepad and sustained thermal,
battery/memory/FPS tests remain. Actual Internet and Railway protocol/auth/API
rollout is not established by synthetic local tests.

No main merge, production deployment, new Archive, upload, processing or Apple
review submission occurred. The existing 1.1.11 (110) archive remains based on
d0b40cb and does not contain the Blast Ball fix. A new release archive must be
built locally with Xcode 27 from a newly frozen and remotely verified source.
