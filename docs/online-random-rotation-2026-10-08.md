# Independent Online Tournament Rotation

Source commit: `bc9f0b2bcab4846cc7b782eb21caf26d333b4ba7`.
Branch: `feature/kras-online-random-rotation`.
Runtime/content/tool fingerprint:
`fe63142d531da9dd563b39d78f73fce0dc2b2b604a4f0c24e8436dc71f75914b`.

## Implemented

The online host now chooses selected arena, independent seeded random arena,
or shuffled arenas without repeats. Random selection draws independently
from the configured entries and can repeat consecutively, including when
there are only two entries; it does not consume a no-repeat bag. The server
accepts this explicit policy while preserving host-only configuration,
readiness and existing tournament accounting. Arabic/English labels and
client choice mapping are tested. Existing manual and no-repeat policies
remain available.

This extends arena selection for the currently selected online game. It is
not a completed mixed-game online playlist builder or all requested rotation
modes. No production endpoint was enabled or reconfigured.

The existing rendered online UI fixture now accepts locale/rotation arguments,
checks the rotation selector, saves isolated outputs, fails on PNG writes,
and captures the scrolled settings as well as the initial view and results.
Its room and scores are synthetic presentation data, not a production room.

## Tests

- New server regressions failed on the parent and pass with the feature.
- Rooms/tournament subset: 71 tests pass, zero skipped/failed.
- Godot network/choice suite: 352 assertions pass, strict test log guard passes.
- Godot full suite, official `--fixed-fps 60` mode: 392151 assertions pass in
  284.3 seconds; strict completed-test log guard passes.
- Final compile check: all 423 scripts compile.
- Server full suite with all six fresh Godot world captures from the full
  run: 240 tests pass, zero skipped/failed.
- Real Metal Mobile UI fixture: Arabic random and English no-repeat, both
  orientations, twelve screenshots total. Final logs pass runtime guard.
  Inspected Arabic portrait random control and English landscape longest
  no-repeat label. Screenshots are not App Store gameplay evidence.

The application/UI/server changes were stable throughout the full Godot run.
Only the presentation tool was subsequently refined while that run was live;
its final form was separately compiled and rendered afterward. Thus these
are scoped local checks, not a clean-checkout CI qualification of the final
commit or an App Store archive.

## Failures Retained

The first full-suite attempt omitted the project's fixed-FPS flag and was
explicitly terminated (143); it is not counted as a completed run. The first
compile command referred to a nonexistent tools script; despite exit zero,
its errors were rejected and the actual compile scene was run successfully.
The isolated server attempt could not bind loopback (EPERM); the local
escalated test passed. A server run without capture environment variables
skipped six tests; the final captured run above skipped none.

Verbose UI shutdown initially retained victory AudioStreamWAV playback.
AudioManager already stops and clears playback references; the immediate
test exit needed the same 100ms audio-worker settling interval as the
existing visual harness. After adding that interval to the test tool, both
language runs complete without leaked-resource warnings. No general audio
runtime change or physical audio acceptance is claimed.

Raw red/green, compile, complete suite, captured server, diagnostic/final UI
logs and two inspected screenshots are retained under
`qa/online-random-rotation-2026-10-08/`. Earlier source campaigns remain running
on their original commit and were not cancelled or relabelled as current.

## Remaining Gates

Final clean-source CI, full content/balance and all-map QA, physical-device
multiplayer/performance/audio/controller acceptance, production deployment
and positive connection, main integration, signed local Xcode 27 archive,
upload, processing and App Review submission remain open. No release-ready
claim, production mutation or Apple submission was made.
