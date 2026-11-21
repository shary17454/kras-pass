# Rendered soak completion guard

## Source and scope

Parent: `ba2ada7c10ce0916f8d499895ff9164380c97150`.
Branch: `feature/kras-online-random-rotation`.
Only test infrastructure changed; gameplay and production configuration did not.

The old exit condition accepted any nonempty steady sample, even when
`complete_duration` was false. A regression test reproduced this: 96 passed,
one failed (`partial steady samples cannot qualify an interrupted soak`).
The exit condition now requires both a complete duration and steady samples.

The soak also drains existing AudioManager playback after recording its
measurements, matching the other test runners. This avoids retaining engine
and music playback resources during process shutdown. Cleanup happens after
sampling and cannot be interpreted as a frame-rate optimization.

## Verification

- Godot 4.7.1 official, local macOS Apple M5, Mobile renderer.
- Focused suite: 97 assertions passed; exit 0.
- Compilation: all 440 scripts compiled; exit 0.
- Rendered sample: tank_arena / tank_foundry, four scripted touch drivers,
  four personal views, no firing, quality 2, 1280x720, 60 FPS cap.
- Requested steady duration: 6 seconds; live duration: 9.01447 seconds
  including warmup; `complete_duration=true`; exit 0.
- Steady: 362 frames, 60.0275 FPS, p95 17.692 ms, worst 21.802 ms.
- Node count: 51 before and after. Strict runtime log guards passed for
  focused tests, compilation and the rendered run.
- Screenshot inspected: four nonblank views, HUD and controls present.

Local evidence:
`/tmp/kras-soak-completion-red.stdout`,
`/tmp/kras-soak-completion-green.stdout`,
`/tmp/kras-soak-completion-compile.stdout`,
`/tmp/kras-soak-completion-rendered.stdout`,
`/tmp/kras-soak-completion-rendered.json`,
`/tmp/kras-soak-completion-rendered.png`.

## Limits and remaining gates

This short drive-only sample does not qualify sustained performance,
projectile stress, iPhone frame rate, energy use or temperature. The earlier
60-second sample on the parent source measured 43.8921 FPS and had shutdown
audio warnings. Do not replace that negative evidence with this short sample
or claim the audio drain improved gameplay performance.

GitHub runs 37877401757 and 37877408528 were still queued when rechecked.
They target the parent commit, not this test-only follow-up. No workflow was
cancelled or restarted. No production deployment, archive, upload or review
submission was performed as part of this change.
