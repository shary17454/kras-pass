# Tag AI observation memory

Tag Hunt previously treated `perceive()`'s unknown-position zero as a real
hunter location. A runner near the centre could flee a phantom threat even
when it had never seen the hunter. The initial reproduction log
`/tmp/kras-tag-cues-before.log` demonstrates two unknown-hunter failures.
An initial third expectation discarded legitimate memory and was corrected:
last-seen information should remain useful without revealing hidden movement.

The shared brain now records first visible observation times per fighter, a
bounded array sized to the roster. `has_observed()` distinguishes unknown
locations from valid origin coordinates, respects the configured reaction
delay and resets between rounds. Tag Hunt retreats safely before any delayed
observation exists; after observing a hunter it continues using the existing
last-seen position history. It does not read hidden movement or velocity.
Other brain selectors and game scoring/network schemas are unchanged.

Terminal verification:

- `/tmp/kras-tag-cues-qualified.log`: 119 assertions passed, exit zero.
  Includes unknown-hunter behavior, visible fleeing and hunting, hidden
  movement isolation, preserved last-seen memory, round reset, first-observation
  delay, valid origin coordinates and invalid slots.
- `/tmp/kras-tag-network.log`: 26 assertions passed, exit zero.
- `/tmp/kras-tag-compile-qualified.log`: 324 scripts compile, exit zero.
- `git diff --check`: passed.

The intermediate pursuit test used a same-time snapshot at a float32 boundary;
the final fixture advances the simulated decision clock past the observation,
as normal gameplay does. The final source does not change history timing.
macOS engine logs retain the known system CA retrieval warning.

Full regression on this latest patch, wall/camera occlusion, overall balance,
physical-device QA and Apple release remain unproven. The running natural
balance campaign `37108335239` uses source
`0b21cac95075705a3ee85641e33e3aa680bcd879`, not this subsequent Tag patch.
Do not attribute that campaign's results to the new source.
