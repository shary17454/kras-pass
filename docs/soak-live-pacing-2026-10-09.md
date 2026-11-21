# Live frame pacing evidence guard

Parent source: 19f21be72a518936c7c0a9b13711fd2d680d255a on
feature/kras-online-random-rotation. Only tests and this evidence note change;
no gameplay, graphics, collision, network, production or iOS settings change.

## Reproduced gap

The rendered soak reported the requested cap, but did not observe the live
Engine.max_fps or window vsync mode. A completed sample could therefore be
accepted without proving its stated sampling conditions. The new regression
failed on the old implementation: 114 passed, one failed, exit 1
(/tmp/kras-pacing-red.stdout). This is a measurement qualification defect,
not proof that shipping settings changed during an earlier benchmark.

## Correction

Each live frame records Engine.max_fps and the window vsync mode. Qualification
requires every sampled frame (warmup included) to have an observation, the
requested cap throughout, and disabled vsync throughout. Any discrepancy is
latched: restoring conditions cannot conceal earlier drift. Distinct values
are retained in a bounded eight-entry list; the validity latch remains active
when the diagnostic list fills. Existing duration/projectile requirements stay
in force. No setting is reset or forced during the sample to make it pass.

The output now includes frame_pacing with frames_observed, requested values,
observed values and matches_requested. Those are engine/window settings,
not proof of actual display presentation frequency or exclusive GPU cost.

## Verification

- Focused final suite: 126 assertions passed, exit 0; log guard passed.
- Compilation: all 442 scripts compiled, exit 0; log guard passed.
- Intermediate live-observation implementation: full 60-second steady run,
  four scripted touch drivers firing, tank_arena/tank_foundry, Mobile renderer,
  1920x1080, quality 2. 3774 live frames recorded cap 0 and vsync 0; observed
  frame count equals warmup plus steady count. Exit 0; mean 59.981035 FPS,
  p95 17.936 ms. This preceded the final count-equality guard.
- Final implementation: original short run paused after 6.766994 live seconds
  and correctly exited 1 with complete_duration=false. Its raw evidence is
  retained. Explicit retry completed 9.000034 live seconds including warmup,
  535 pacing observations, all cap 0/vsync 0, six live weapons, 51 nodes before
  and after. Exit 0; runtime guard passed. Its six-second steady sample is an
  integration check, not sustained device performance evidence.
- Full headless regression: 396259 assertions passed in 199.0 seconds,
  exit 0; its completed log passed the tests guard independently. Headless
  fixed-step simulation is not evidence of physical-device frame pacing.

Evidence: /tmp/kras-pacing-{red,final-green,compile,render,final-render,
final-render-retry,full}.stdout and corresponding rendered JSON/PNG files;
copies in ../qualification-soak-pacing-2026-10-09/.

## Remaining product gates

Observed uncapped engine settings still produced roughly 60 FPS on this Mac;
the cause is not established by this patch. It does not implement or qualify
120 FPS on iPhone/iPad, optimize collisions, establish battery/thermal behavior,
complete the 146 requirements, or accept the stage release gates.

Balance fingerprint remains
52c9c04a4255101a89e80f3a50fc8ea92e145e1b3c9c0a9d2ab778f90dc7465e.
Tests/docs are outside that fingerprint; exact commit identity remains distinct.
The current network/balance campaigns retain their 19f21be checkout and are
not cancelled by this test-only correction. No main merge, Railway database
operation, production deployment, archive, upload or submission is performed.
