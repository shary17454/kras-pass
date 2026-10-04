# Tournament Resource Prefetch Qualification

## Scope

The local tournament now retains resources for its immediately following game
after the current match has finished. It does not preload while that match is
playing. Standings confirm the next configuration after recording the result,
including an early cup victory or a result-dependent decider. The transition
adopts the retained resources rather than issuing duplicate threaded requests.

`TournamentSession.following_config()` is a pure preview: it does not advance
the schedule, score, persistence checkpoint or seeded choices. The ordinary
configuration builder remains shared with the preview.

Cancellation stops requesting subsequent resources. Godot cannot cancel a
native threaded load, so an outstanding request is drained only after it has
finished. A superseded job cannot mark a newer bank ready. Screen identity
guards reject delayed callbacks from a screen that has been left. Leaving the
party or completing it releases its future resource plan.

Online future maps are not predicted by this local optimization. Scene geometry
construction and GPU pipeline compilation still happen during scene setup.
This does not prove faster iPhone loading or reduced battery/thermal load.

## Evidence

Executed with Godot 4.7.1 on macOS, using isolated save directories:

| Check | Result | Log |
| --- | --- | --- |
| All script compilation | 348 scripts passed | `/tmp/kras-prefetch-final-compile.log` |
| Prefetch lifecycle, cancellation, replacement, early cup ending | 68 assertions passed | `/tmp/kras-prefetch-final.log` |
| Same suite with actual Metal rendering | 68 assertions passed | `/tmp/kras-prefetch-metal.log` |
| Existing party/progression regression suites | 4171 assertions passed | `/tmp/kras-prefetch-party.log` |
| Existing resource preparation regression | 737 assertions passed | `/tmp/kras-prefetch-regression.log` |

The log guard passed for the final compilation, headless prefetch, Metal
prefetch and party runs. The earlier preparation run passed with no script
errors or failure/leak markers found in its log. All owned processes completed.

The actual router test traverses match -> standings -> next match -> main menu,
using controlled legal phase transitions. This verifies resource ownership and
result callback integration, not natural gameplay, balance, touchscreen UX or
real-device performance. Pending loader cancellation/replacement tests use a
controlled loader; real Godot threaded resource adoption is tested separately.

The initial test development run called a nonexistent MatchConfig.to_dict
method. That run is not accepted as passing despite its runner summary. The
corrected tests compare stored script properties directly.

## Release Gates Still Open

- Full final-source CI and the remaining network qualification matrix.
- Integration into the approved release source, without changing main here.
- Both-orientation real-device gameplay, frame pacing, battery and thermal QA.
- Production Railway/client protocol coordination and post-deployment checks.
- New exact-source Distribution archive, signature verification, upload,
  App Store Connect processing and submission verification.

This branch is an implementation review, not an App Store submission.
