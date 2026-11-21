# Four Local Touch Regions On Current Source

Inspected source: `f2dcfd32b8cda63d68c3a9ea7a52958b6fda3840`.
Runtime fingerprint: `39854bc0220d9911c43a4fce98c0d35dcc562dae73d196c9475c213c06d98e93`.
Source stayed unchanged during the probe; the post-run fingerprint matches.
Evidence directory: `qa/four-local-current-2026-10-08/`.

## Actual Renderer Probe

Official Godot 4.7.1, Metal Forward Mobile on the Apple M5 Mac, Dummy audio.
Existing import/shader caches reused. All 39 catalogue games, each default
arena, Arabic, four touch-controlled human slots and zero bots, landscape
1280x720 and portrait 540x960, two extra play seconds after legal intro and
countdown transitions. The fixture does not inject human touch gestures.

78 captures completed; zero failures; process exit zero; runtime log guard
passed. Independently checked every expected game/orientation pair exactly
once, four touch slots [0,1,2,3], enclosing control bounds, PLAYING phase,
saved PNG existence and actual PNG dimensions. Full PNGs remain under
`/tmp/kras-first-response-all39-four-ar-save/screenshots/`.

Reviewed and retained actual Tank Arena landscape/portrait and Goal Guard
portrait images. Tank views share one simulation and show four independent
cameras; portrait controls use two rows of two player regions. Goal Guard uses
one shared court with four distinct control regions. These images show the
configured player symbols alongside colors, not a color-only identity.

This is not all-map coverage, gameplay completion, physical multi-touch,
controller support, English four-player QA, manual polish of every screenshot,
stable FPS, cold startup, audible audio, battery or thermal acceptance. The
automated nonblank/control checks do not make all games READY.

## Pinned Remote Qualification

Started and verified source head for the new runs, without cancelling old jobs:

- Quality/network: https://github.com/shary17454/kras-pass/actions/runs/37734706891
- Natural balance: https://github.com/shary17454/kras-pass/actions/runs/37734724695

Both are pinned to f2dcfd3, not the preceding 7f270c5 source. Balance uses seed
offset 2700000. The latest observed quality state has one completed job,
three in progress and 37 queued; balance has its catalogue job queued.
Neither complete campaign nor full network success is claimed. No final iOS
archive, production synchronization, upload or App Review submission occurred.
