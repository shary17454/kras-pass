# Rendered transition QA - 2026-10-06

Source parent: `5870ddc56b72dba6d2636f866e54882042eea147`.

## Failure and fix

The real rendered party QA aborted when cold match resource preparation took
longer than its 40-frame wait. The harness invoked `_set_phase` on the previous
main menu. The failed process was stopped; its output is retained at
`/tmp/kras-pr128-party-visual.stdout`.

The harness now awaits Router transitions, including `start_match`, and checks
the actual match scene and game ID before accessing match controls. Runtime
loading behavior and gameplay are unchanged. Frame settling remains for layout,
not as a resource-loading completion barrier.

## Verified rendered run

Godot 4.7.1, Apple M5, macOS OpenGL compatibility renderer; isolated saves.
`/tmp/kras-transition-visual.stdout`: exit 0, `PARTY VISUAL CHECK: 0 failures`.
Strict runtime log guard passed. Arabic and English UI, 1280x720 and 540x960,
including four-touch ring, tank and race scenes were captured. Race images in
both orientations were inspected and show players above the control regions.
Captures are fixtures at the start of a match, not evidence of a complete human
tournament or App Store screenshot qualification.

OpenGL reported unsupported BPTC_RGBA compression and converted textures to
RGBA8; screen-space AA is unavailable on this renderer. These are recorded
warnings, not iPhone Metal performance measurements.

## Performance evidence, not a passing 60 FPS gate

`/tmp/kras-transition-perf.stdout`, serial after visual QA, four moving Bots,
real rendered frames, no forced fixed FPS, resource preparation enabled:

| Game | Samples | Live seconds | Mean ms | p95 ms | Worst ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| sabaq_sawarikh | 482 | 10.00 | 18.70 | 24.81 | 72.48 |
| tank_arena | 400 | 10.73 | 24.37 | 42.76 | 74.57 |

Both sample budgets completed. All four Bots moved. Nodes returned to 51,
matching the initial count. This does not establish long-term memory stability.
The probe exits zero when samples exist, so zero exit is NOT proof of 60 FPS.
Both measured means miss the 16.67 ms target on this renderer. Frame-correlated
slow-frame records are not CPU call-stack profiles.

## Remaining release gates

Investigate frame costs without removing required gameplay or visuals; compare
native rendering and verify on an actual supported iPhone. Heat, battery,
four-human play and controller QA remain unverified. Earlier character balance
flags and server/client rollout gates remain open. No archive, signing, upload,
Railway deploy or App Review submission was performed by this change.
