# Routed Menu Navigation

The older navigation check in test_systems constructs detached screens and
checks that go_back exists. It does not invoke that action for each screen.
test_routed_navigation now opens each of the 25 non-menu, non-match routes
through SceneRouter, invokes the screen's real back action, and follows its
intended back chain until main_menu. Replay playback legitimately returns to
the replay library first; the test preserves this flow rather than changing UI.

The matrix uses Arabic and English at portrait 540x960 and landscape 1280x720
window sizes: 100 route visits. Each transition checks one live holder child,
previous screen release via WeakRef, final menu identity and unlocked router.
Repeated route IDs and a bounded transition deadline expose navigation loops
or stuck transitions. Locale and window size are restored after the fixture.
Test storage is isolated from user data. No account login, server deployment,
production data change or device installation is performed.

Focused run: 1110 passing assertions, 1.4 seconds, exit 0; strict Godot log
checker passed. Compilation: 439 scripts, exit 0; log checker passed.
Full regression: 395243 passing assertions, 205.5 seconds, exit 0; strict
Godot log checker passed. Expected negative-case diagnostics and the documented
sandbox CA warning remain in the raw log; they are not described as no warnings.
The initial test incorrectly required direct replay-to-menu navigation and failed;
this was a fixture correction, not a reproduced product defect.

This establishes menu construction and back-flow coverage, not pixel QA,
physical touch/gamepad operation or mobile performance. Results and replay
routes use their safe empty-data entry; populated flows remain separate tests.
Match navigation and natural tournament completion are covered separately in
test_tournament_flow. It does not mark all product stages or games READY.

The runtime balance fingerprint remains
71b5a52a33d4be33e306e93acdc777fdf3b7de41c82e8e463cbc88bd7901ed7c.
This change is tests/documentation only. An existing archive's captured commit
is not relabeled with the subsequent test commit.
