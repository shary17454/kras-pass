# Current-source content gate

Inspected clean branch `feature/kras-online-random-rotation`, source
`0fee3c06229385f87f6141e16554e88a1cddee21`, simulation fingerprint
`3c4a6722c287b7c486e51f875ee80350949c5fe06eaa37bf814f90e795bfb746`.

Ran `tools/party_content_audit.tscn` with isolated test saves and the retained
current-source Crate Smash natural report
`docs/qa/crate-player-clearance-2026-10-08.json` as a recheck. Exit 0 and strict
runtime guard passed. No gameplay or acceptance thresholds were edited.

## Observed classification

- 39 definitions, 8 characters, 34 arenas, 22 powerups.
- Structural validation errors: none.
- READY 0, NEEDS_POLISH 1, NEEDS_BALANCE 38, REWORK 0, BROKEN 0.
- Crate Smash has the current-source natural sample and remains NEEDS_POLISH,
  not READY. Device/gameplay/performance acceptance is still absent.
- The other 38 entries lack sufficient current-source evidence in this audit.
  This is not a claim that those games are unimplemented or broken.

Historical campaign `37754749544` is terminal successful on `1c52aae...`,
not the current simulation source. Its six retained warning entries are not
erased by this audit or by newer small samples. The audit's exit 0 verifies
its structural gate, not release acceptance.

Raw audit and classifications: `qa/current-content-gate-2026-10-08/`.
The first local audit request did not execute because automatic permission
review timed out; the permitted single retry above ran successfully.

## Current-source campaigns

After confirming the previous same-branch campaign was terminal, dispatched
Natural Balance Campaign `37770437501` at the exact current SHA above with
independent seed offset 4000000. The workflow retains 24 natural baseline,
16 mirrored difficulty and two stress matches per game, maximum three
concurrent simulation jobs, and explicit source/engine checks. These are
1638 planned matches, not 1638 completed matches at this checkpoint.
Live inspection verified checkout SHA, catalogue success and queued/running
simulation jobs. No new game report or final successful campaign is claimed.

Core run `37768869605` on `babcf829532f7882fcbe2f8dc81fa01299ede065` remains
in progress at the last observation. The descendant source changes since
that commit are documentation only for src/data/native/tests/server and
quality workflow; this does not turn an unfinished run into passing evidence.

No old job was cancelled/restarted. Both workflows are Linux Godot/server QA,
not Xcode Cloud. No main merge, Railway promotion, Apple archive/upload or
review submission was performed. Device, current content/balance/visual and
performance gates must close before release; no release-ready claim is made.
