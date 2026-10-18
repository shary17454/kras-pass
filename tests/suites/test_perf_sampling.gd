extends RefCounted

func run(t: TestHarness, _host: Node) -> void:
	t.suite("rendered performance sampling budget")
	var probe: Node = load("res://tests/perf.gd").new()
	probe._configure_games(PackedStringArray(["--all"]))
	t.equal(probe._games.size(), Registry.all_minigames().size(), "all-game rendered sweep includes the complete catalogue")
	for definition in Registry.all_minigames():
		t.ok(definition.id in probe._games, "rendered sweep includes " + definition.id)
	probe._configure_games(PackedStringArray(["--all", "--games=boss_forge,ring_rumble"]))
	t.equal(probe._games, ["boss_forge", "ring_rumble"], "explicit probe selection overrides the all-game sweep")
	probe._samples.resize(400)
	probe._live_seconds = 2.0
	t.ok(not probe._sample_budget_met(), "fast rendering cannot substitute for simulation time")
	probe._live_seconds = 10.0
	t.ok(probe._sample_budget_met(), "ten live seconds and 400 rendered samples satisfy budget")
	probe._samples.resize(399)
	t.ok(not probe._sample_budget_met(), "simulation time alone cannot substitute for rendered samples")
	probe._samples.resize(400)
	probe._live_seconds = 9.999
	t.ok(not probe._sample_budget_met(), "minimum live duration is not rounded up")
	probe._samples.clear()
	probe._live_seconds = 0.5
	t.ok(probe._should_finish(true), "an early round ending never waits to fill the budget")
	t.ok(not probe._should_finish(false), "a live short sample continues below the wall ceiling")
	probe._elapsed = 24.999
	t.ok(not probe._should_finish(false), "wall ceiling is not rounded up")
	probe._elapsed = 25.0
	t.ok(probe._should_finish(false), "wall ceiling ends the probe without a full budget")
	probe._record_slow_frame(24.999, {})
	probe._record_slow_frame(NAN, {})
	probe._record_slow_frame(INF, {})
	t.equal(probe._slow_frame_count, 0, "trace excludes normal and non-finite frame times")
	var measurements := {"scores": [1, 2]}
	for index in 20:
		probe._record_slow_frame(25.0 + index, measurements)
	measurements.scores[0] = 999
	t.equal(probe._slow_frame_count, 20, "trace counts every slow frame without retaining all samples")
	t.equal(probe._slow_frames.size(), 8, "trace memory remains bounded to eight frames")
	t.equal(probe._slow_frames[0].frame_ms, 44.0, "trace retains the worst interval first")
	t.equal(probe._slow_frames[7].frame_ms, 37.0, "trace retains the eight worst intervals")
	t.equal(probe._slow_frames[0].scores[0], 1, "later game state cannot mutate captured trace evidence")
	probe.free()
	var soak: Node = load("res://tests/soak_perf.gd").new()
	soak.game = "tank_arena"
	soak.arena_id = "tank_oasis"
	t.equal(soak._configuration_error(), "", "authored tank arena is accepted")
	for humans in range(5):
		soak.humans = humans
		t.equal(soak._configuration_error(), "", "zero to four local input slots are valid for vehicle sampling")
	for humans in [-1, 5]:
		soak.humans = humans
		t.ok(not soak._configuration_error().is_empty(), "invalid human count cannot mislabel the sampled workload")
	soak.humans = 4
	soak.game = "ring_rumble"
	soak.arena_id = ""
	t.ok(not soak._configuration_error().is_empty(), "driving fixture cannot qualify nonvehicle controls")
	var touch := TouchSource.new()
	for time in [0.0, 3.0, 100.0]:
		soak.drive_touch(touch, time)
		t.near(touch._move.length(), 1.0, 0.001, "scripted joystick retains normal movement magnitude")
		t.ok(absf(touch._steer) <= 0.6, "scripted steering stays inside ordinary input range")
		t.equal(touch._throttle, 1.0, "steering control scheme receives throttle")
		t.equal(touch._bits, 0, "drive-only sample does not claim a projectile stress test")
	touch.free()
	soak.game = "tank_arena"
	soak.arena_id = "tank_oasis"
	soak.firing = true
	t.equal(soak._configuration_error(), "", "firing workload accepts ordinary local tank controls")
	soak.game = "sabaq_sawarikh"
	soak.arena_id = ""
	t.ok(not soak._configuration_error().is_empty(), "tank firing fixture cannot qualify another game's weapons")
	soak.game = "tank_arena"
	soak.arena_id = "tank_oasis"
	var shooter := TouchSource.new()
	for slot in 4:
		shooter.slot = slot
		var pressed_at := 0.9 - slot * 0.2
		soak.drive_touch(shooter, pressed_at + 0.01, true)
		t.equal(shooter._bits, InputFrame.Btn.ATTACK, "firing fixture presses only the ordinary attack action")
		t.near(shooter._move.length(), 1.0, 0.001, "firing retains normal driving magnitude")
		soak.drive_touch(shooter, pressed_at + 0.3, true)
		t.equal(shooter._bits, 0, "firing releases between pulses for just-pressed actions")
	shooter.free()
	soak.humans = 0
	t.ok(not soak._configuration_error().is_empty(), "scripted firing cannot mislabel a bot-only probe")
	soak.firing = false
	soak.game = "tank_arena"
	soak.arena_id = "tank_oasis"
	soak.arena_id = "dune_ruins"
	t.ok(not soak._configuration_error().is_empty(), "unknown arena cannot silently qualify its fallback")
	soak.arena_id = "sky_causeway"
	t.ok(not soak._configuration_error().is_empty(), "valid arena for another game is rejected")
	soak.arena_id = "tank_oasis"
	soak.game = "missing_game"
	t.ok(not soak._configuration_error().is_empty(), "unknown minigame is rejected before construction")
	soak.game = "tank_arena"
	for duration in [0.0, -1.0, NAN, INF]:
		soak.seconds = duration
		t.ok(not soak._configuration_error().is_empty(), "invalid duration cannot produce qualified evidence")
	soak.seconds = 30.0
	soak.cap = -1
	t.ok(not soak._configuration_error().is_empty(), "negative frame limit is rejected")
	soak.cap = 0
	t.equal(soak._configuration_error(), "", "uncapped rendering remains available")
	for tier in [-1, 4]:
		soak.quality = tier
		t.ok(not soak._configuration_error().is_empty(), "unknown quality tier is rejected")
	soak.quality = 2
	soak.arena_id = ""
	t.equal(soak._configuration_error(), "", "empty arena selects the game's authored default")
	for invalid in [NAN, INF, 50.0, -1.0]:
		soak._record_slow_frame(invalid, {})
	t.equal(soak.slow_frames.size(), 0, "soak ignores normal and invalid frame times")
	var data := {"pipeline_delta": {"draw": 1}, "focused": true}
	for index in 20:
		soak._record_slow_frame(51.0 + index, data)
	data.pipeline_delta.draw = 999
	t.equal(soak.slow_frames.size(), 8, "soak diagnostics retain only eight slow frames")
	t.equal(soak.slow_frames[0].frame_ms, 70.0, "soak retains worst frame first")
	t.equal(soak.slow_frames[7].frame_ms, 63.0, "soak retains worst eight frames")
	t.equal(soak.slow_frames[0].pipeline_delta.draw, 1, "soak copies nested diagnostics at capture")
	soak._record_frame_pacing(soak.cap, DisplayServer.VSYNC_DISABLED)
	soak.report["complete_duration"] = true
	t.equal(soak._result_exit_code(), 1, "no steady samples cannot qualify a completed soak")
	soak.samples.append(16.0)
	soak.report["complete_duration"] = false
	t.equal(soak._result_exit_code(), 1, "partial steady samples cannot qualify an interrupted soak")
	soak.report["complete_duration"] = true
	t.equal(soak._result_exit_code(), 0, "complete duration with steady samples qualifies measurement only")
	soak.firing = true
	t.equal(soak._result_exit_code(), 1, "a firing sample without observed projectiles cannot qualify weapon workload")
	soak.projectile_peak = 1
	t.equal(soak._result_exit_code(), 0, "completed firing sample requires an observed live projectile")
	soak.free()
	var unobserved: Node = load("res://tests/soak_perf.gd").new()
	unobserved.report["complete_duration"] = true
	unobserved.samples.append(16.0)
	t.equal(unobserved._result_exit_code(), 1, "requested pacing without live observation cannot qualify a measurement")
	unobserved._record_frame_pacing(60, DisplayServer.VSYNC_DISABLED)
	t.equal(unobserved._result_exit_code(), 0, "live pacing matching the request qualifies the sampling conditions")
	unobserved._record_frame_pacing(120, DisplayServer.VSYNC_DISABLED)
	unobserved.samples.append(16.0)
	t.equal(unobserved._result_exit_code(), 1, "an unexpected frame cap invalidates the requested workload")
	unobserved._record_frame_pacing(60, DisplayServer.VSYNC_DISABLED)
	unobserved.samples.append(16.0)
	t.equal(unobserved._result_exit_code(), 1, "restoring the cap cannot conceal earlier pacing drift")
	t.equal(unobserved._frame_pacing_frames, 3, "every live frame contributes to pacing observation")
	t.equal(unobserved._frame_pacing_values.size(), 2, "repeated pacing values do not grow diagnostic memory")
	for limit in range(1, 21):
		unobserved._record_frame_pacing(limit, DisplayServer.VSYNC_DISABLED)
		unobserved.samples.append(16.0)
	t.equal(unobserved._frame_pacing_values.size(), 8, "unique pacing diagnostics remain bounded")
	t.equal(unobserved._result_exit_code(), 1, "bounded diagnostics cannot erase the invalid condition")
	unobserved.free()
	var unlimited: Node = load("res://tests/soak_perf.gd").new()
	unlimited.cap = 0
	unlimited.report["complete_duration"] = true
	unlimited.samples.append(16.0)
	unlimited._record_frame_pacing(0, DisplayServer.VSYNC_DISABLED)
	t.equal(unlimited._result_exit_code(), 0, "zero cap is valid only when observed during sampling")
	unlimited.samples.append(16.0)
	t.equal(unlimited._result_exit_code(), 1, "every collected frame needs pacing evidence")
	unlimited._record_frame_pacing(0, DisplayServer.VSYNC_DISABLED)
	t.equal(unlimited._result_exit_code(), 0, "complete per-frame pacing coverage restores sampling validity")
	unlimited._record_frame_pacing(0, DisplayServer.VSYNC_ENABLED)
	unlimited.samples.append(16.0)
	t.equal(unlimited._result_exit_code(), 1, "vsync drift invalidates throughput sampling even when the engine cap matches")
	unlimited.free()
