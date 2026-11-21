# Rendered Hover-Machine Cue Qualification

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-hover-machine-cue-perception.
Runtime/test commit: d8ca9c19ae6ed6f08ecd2dfa0c501c43ccf3d6ef.
Parent: 5f591e6c0a992c447380e9640fff96db5bb0193a.

## Corrected Contract

AI no longer reads the machine's pending item, target slot, unrendered target
point or internal mark carrier directly. A visual_observation API requires
the shared camera/visibility/occlusion predicate:

- Warning location comes from the actual floor ring; severity comes from
  the visible eye's emission colour. Both must currently be observable.
- A neutral gold warning alone does not prove a falling collectible. An
  original gold crate preview now identifies DROP visibly to humans and AI.
  It hides on reset/fire and follows the rendered warning location.
- Mark identity is associated with a currently observable fighter at the
  actual visible marker location. Hidden or ambiguous carriers are unknown.
- Each warning/mark episode has an identity; new episodes, changed rendered
  severity/drop classification and loss of visibility invalidate history.
- AI keeps at most HISTORY_CAP samples per cue, uses its reaction deadline,
  delays moving preview positions and clears both channels at round reset.
- Generic evasion uses the sampled visible machine origin, not its live
  unsampled transform. Existing state getters remain for replay/tooling.

The machine model and mark are now also created in headless simulation;
previously the headless path had no actual visual cue geometry. Replay
event payloads, item delivery, game rules, player speed, scoring and network
schema are unchanged. AI decisions and RNG consumption can change, so old
balance reports do not qualify this source. Headless geometry construction
adds work and must be retained in subsequent performance measurements.

## Focused Evidence

Actual ring_rumble scenes, all four difficulties: 93 assertions pass.
The suite covers first visibility, deadline, hidden ring/eye, reappearance,
private target/item changes without redraw, new crate preview, delayed moving
preview, 32-sample history bound, hidden carrier, round and machine resets.
Rendered coordinates are compared within 0.00001 for float transform error.

Logs: /tmp/kras-hover-cue-final.log and /tmp/kras-hover-cue-compile.log.
The early suite had a test type-inference error, then exposed a null eye in
the existing headless path. Those runs are retained, not called passes:
/tmp/kras-hover-cue-focused.log and /tmp/kras-hover-cue-focused-recheck.log.
The latter exited 0 after a runtime exception; strict log checking remains
required and that run is rejected as evidence.

Mac OpenGL Compatibility visual smoke: two nonblank captures, zero failures,
after ten seconds of real simulation per orientation. Both images were
visually inspected. Existing unsupported screen-space AA warning retained.
This is not physical-device performance or an isolated crate-preview QA:
/tmp/kras-hover-cue-visual/screenshots/ring_rumble-landscape.png
/tmp/kras-hover-cue-visual/screenshots/ring_rumble-portrait.png
Log: /tmp/kras-hover-cue-visual.log.

## Final Exact-Source Gate

The full gate on d8ca9c19ae6ed6f08ecd2dfa0c501c43ccf3d6ef exited 0:

- 403 scripts compile; inventory: 496 resources, 22 autoloads, 27 routes,
  eight characters, zero issues.
- 373106 assertions passed in 443.8 seconds.
- Separate real three-lap race and six boss regression probes passed.
- Stability: 39 matches, zero failures. Materials, meshes, textures and
  audio PCM caches drained to zero; settled memory: 141771789 bytes.
  One cache-release cycle does not prove long-term leak absence.
- All stages passed the existing strict log guards. Stability deliberately
  invokes its OS memory-warning fixture.
- Server: 204 passed, zero failures/cancellations/skips, 1905.280417 ms,
  with all six current-run world fixture variables supplied.

Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.DLNyda
Logs: /tmp/kras-hover-cue-full.log and /tmp/kras-hover-cue-server.log.
Runtime/tests stayed unchanged throughout qualification. The Mac rendering
probe ran concurrently for part of the full gate; elapsed timings are not
performance measurements or evidence of performance improvements.

Draft PR: https://github.com/shary17454/kras-pass/pull/158, based on the
first-rival acquisition branch. Task attachment failed at the existing
100-identity cap; no unrelated task attachment was removed.

## Remaining Acceptance

One ring_rumble sample completed naturally on this exact source: 24 baseline,
16 matched-seed/character difficulty comparisons and two mutator matches.
Seed offset: 600000. Exit 0 and strict log guard passed. Fingerprints before
and after both equal
1f5573ce2713efdb7e8e14b91d6231164d96a613076de9405e3795d95847e3f2.
Expert edge: 0.55; slot bias: 0.19; character bias: 0.075; average natural
duration: 41.0673611111101 seconds; baseline tie rate: 1/24. No simulator
flags. Retain the 19-percentage-point slot difference for independent QA;
absence of flags does not establish good balance. No paired pre-change
campaign was run and no improvement or READY promotion is claimed.
Report: hover-machine-ring-natural-600000.json.
Log: /tmp/kras-hover-cue-natural.log.

No all-game current-source natural balance or Internet/four-peer acceptance
is established for this source. Physical iPhone/iPad cue readability, performance, thermal,
battery and sustained gameplay remain unverified. Other AI/perception and
content requirements must still pass their own audits. No main merge,
production backup/migration/rollout, new signed local Xcode 27 Archive,
Apple upload/processing or review submission is established here.
