extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay seek lifecycle")
	var errors_before := Log.error_count()
	var cfg := MatchConfig.build("zone_hold", ["nabta", "sakhra"], 0, 1, 31337)
	cfg.duration_override = 1.0
	cfg.rounds = 2
	cfg.sudden_death = false
	var packets: Array = []
	for tick in 122:
		var packet := PackedByteArray()
		for slot in cfg.player_count():
			var frame := InputFrame.new()
			frame.bits = InputFrame.Btn.DASH if tick == 0 else 0
			packet.append_array(frame.encode())
		packets.append(packet)
	var recording := ReplayData.from_match(cfg, packets, {}, {}, null)
	var scene = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"replay": recording})
	scene.set_physics_process(false)
	var progress: Array[int] = []
	scene.playback_progress.connect(func(tick, _total): progress.append(tick))
	scene.playback_paused = true
	scene.pb_set_speed(0.5)
	scene.hud.visible = false
	scene.camera.configure(ArenaCamera.Mode.TOP_DOWN, scene.arena)

	t.test("seek from preparation initializes the round before consuming inputs")
	scene.pb_seek(20)
	t.equal(scene.phase, MatchPhase.P.PLAYING, "seek enters live phase")
	t.equal(scene.ctx.phase, scene.phase, "context phase agrees")
	t.equal(scene.playback_tick, 20, "requested frame reached")
	t.equal(scene._tick_index, 20, "simulation tick agrees with recording")
	t.near(scene.ctx.time_left, 1.0 - 20.0 / 60.0, 0.00001, "round clock starts at full duration")
	var zone: Vector3 = scene.controller.zone_position
	var timer: float = scene.controller._move_timer
	var rng_state: int = scene.ctx.rng.state

	t.test("backward seek rebuilds seeded controller state and input edges")
	scene.pb_seek(45)
	scene._speed_accum = 0.75
	scene.desync_tick = 30
	scene.playback_drift = 9.0
	scene.pb_seek(20)
	t.equal(scene._tick_index, 20, "rewind resets checkpoint and event clock")
	t.near(scene.ctx.time_left, 1.0 - 20.0 / 60.0, 0.00001, "rewind restores round clock")
	t.near(scene.controller.zone_position.distance_to(zone), 0.0, 0.00001, "controller position reproduces")
	t.near(scene.controller._move_timer, timer, 0.00001, "controller timer reproduces")
	t.equal(scene.ctx.rng.state, rng_state, "seeded RNG reproduces")
	t.equal(scene.desync_tick, -1, "stale desync cleared")
	t.equal(scene.playback_drift, 0.0, "stale correction drift cleared")
	t.equal(scene._speed_accum, 0.0, "fractional playback step cleared")
	t.ok(scene.playback_paused, "seek preserves pause")
	t.equal(scene.playback_speed, 0.5, "seek preserves speed")
	t.ok(not scene.hud.visible, "seek preserves HUD visibility")
	t.equal(scene.camera.mode, ArenaCamera.Mode.TOP_DOWN, "seek preserves camera mode")

	t.test("restart leaves sudden death through a fresh match lifecycle")
	scene._set_phase(MatchPhase.P.SUDDEN_DEATH)
	t.ok(scene.ctx.sudden_death and scene._sudden_death_used, "sudden death entry hook executed")
	t.ok(scene.controller.zone_radius < scene.controller.BASE_RADIUS, "controller entered sudden death")
	scene.pb_seek(0)
	t.equal(scene.phase, MatchPhase.P.PLAYING, "restart leaves sudden death")
	t.ok(not scene.ctx.sudden_death and not scene._sudden_death_used, "sudden death flags reset")
	t.near(scene.controller.zone_radius, scene.controller.BASE_RADIUS, 0.00001, "controller rebuilt at normal radius")
	t.near(scene.ctx.time_left, 1.0, 0.00001, "sudden death clock replaced with round clock")

	t.test("fast playback stops live ticks on entry to FINISH")
	scene.pb_seek(59)
	scene.playback_paused = false
	scene.pb_set_speed(4.0)
	scene._physics_process(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.FINISH, "round reaches FINISH")
	t.equal(scene.playback_tick, 60, "speed multiplier does not consume finish frames")
	t.equal(scene._tick_index, 60, "finish does not advance checkpoint clock")
	scene.playback_paused = true
	scene.pb_set_speed(0.5)
	scene.pb_seek(20)
	t.equal(scene.phase, MatchPhase.P.PLAYING, "rewind from FINISH restores play")
	t.near(scene.ctx.time_left, 1.0 - 20.0 / 60.0, 0.00001, "rewind from FINISH restores clock")

	t.test("forward seek crosses round finish and preparation without consuming phantom ticks")
	scene.pb_seek(80)
	t.equal(scene.playback_tick, 80, "second round target reached")
	t.equal(scene._round_index, 1, "next round lifecycle executed")
	t.equal(scene._round_results.size(), 1, "first round completed exactly once")
	t.equal(scene.phase, MatchPhase.P.PLAYING, "second round is live")
	t.equal(scene._tick_index, 80, "non-live phases do not advance recording clock")
	t.greater(scene.ctx.time_left, 0.0, "second round clock initialized")

	t.test("restart from DONE clears sudden death and completion state")
	for step in 1200:
		if scene.phase == MatchPhase.P.DONE:
			break
		scene.playback_paused = false
		scene._physics_process(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.DONE, "normal playback actually reaches DONE")
	scene.playback_paused = true
	scene.pb_seek(0)
	t.equal(scene.phase, MatchPhase.P.PLAYING, "restart can resume from DONE")
	t.equal(scene.ctx.phase, MatchPhase.P.PLAYING, "context leaves DONE too")
	t.equal(scene.playback_tick, 0, "restart lands exactly at zero")
	t.equal(scene._tick_index, 0, "simulation clock reset")
	t.near(scene.ctx.time_left, 1.0, 0.00001, "restart restores full clock")
	t.equal(scene._round_index, 0, "round index reset")
	t.empty(scene._round_results, "old results discarded")
	t.ok(not scene.ctx.sudden_death and not scene._sudden_death_used, "sudden death cleared")
	t.near(scene.controller.zone_radius, scene.controller.BASE_RADIUS, 0.00001, "controller sudden-death state cleared")
	t.ok(not scene.ctx.early_finish and not scene._phase_locked, "completion flags cleared")
	t.equal(progress.back(), 0, "transport receives zero progress")
	t.equal(InputRouter.frame(0).bits, 0, "stale held input cleared")
	t.equal(InputRouter.frame(0).prev_bits, 0, "stale previous input cleared")
	scene.playback_paused = false
	scene.pb_set_speed(1.0)
	scene._physics_process(1.0 / 60.0)
	t.equal(scene.playback_tick, 1, "normal physics resumes after restart")
	t.ok(InputRouter.frame(0).just_pressed(InputFrame.Btn.DASH), "first recorded press is an edge again")
	t.equal(Log.error_count(), errors_before, "lifecycle logs no errors")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await _pooled_world(t, host)


func _pooled_world(t: TestHarness, host: Node) -> void:
	t.test("repeated restart retires old pooled world and signal subscriptions")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra"], 0, 1, 4242)
	var packet := PackedByteArray()
	for slot in cfg.player_count():
		packet.append_array(InputFrame.new().encode())
	var recording := ReplayData.from_match(cfg, [packet], {}, {}, null)
	var scene = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"replay": recording})
	scene.set_physics_process(false)
	var children: int = scene.get_child_count()
	var signals := [EventBus.player_hit, EventBus.score_changed, EventBus.player_eliminated,
		EventBus.match_phase_changed, EventBus.match_time_changed]
	var connections: Array[int] = []
	for event in signals:
		connections.append(event.get_connections().size())
	# Exercise the real outer player's callbacks without replacing its labels.
	var player = load("res://src/ui/screens/replay_player.gd").new()
	player.replay = recording
	player.match_scene = scene
	var transport: Control = player._transport()
	host.add_child(transport)
	scene.playback_progress.connect(player._on_progress)
	scene.desync_detected.connect(player._on_desync)
	for attempt in 3:
		InputRouter.push_virtual(0, Vector2.ONE, Vector2.ONE, InputFrame.Btn.DASH)
		scene.pb_seek(0)
		t.equal(scene.get_child_count(), children, "world children do not accumulate")
		for index in signals.size():
			t.equal(signals[index].get_connections().size(), connections[index], "world event subscriptions do not accumulate")
		t.ok(InputRouter.playback_mode, "router remains exclusively replay driven")
		for slot in cfg.player_count():
			t.equal(InputRouter.source_of(slot), InputRouter.Source.VIRTUAL, "slot retains virtual source")
			t.equal(InputRouter.frame(slot).bits, 0, "input frame retired")
			t.equal(InputRouter._virtual_pending[slot].bits, 0, "pending source input retired")
		t.ok(scene.playback_progress.is_connected(player._on_progress), "outer progress callback retained")
		t.ok(scene.desync_detected.is_connected(player._on_desync), "outer desync callback retained")
		scene.playback_progress.emit(1, recording.tick_count())
		t.equal(player._scrub.value, 1.0, "outer callback updates existing transport")
		player._toggle_hud()
		t.equal(scene.hud.visible, player._hud_visible, "outer HUD callback resolves rebuilt HUD")
		player._cycle_camera()
		t.equal(scene.camera.mode, player._camera_modes[player._camera_index], "outer camera callback resolves rebuilt camera")
		t.ok(scene.machine != null and scene.machine.scripted, "scripted machine rebuilt")
		for key in Pool._pools:
			for node in Pool._pools[key]:
				t.ok(is_instance_valid(node) and not node.is_queued_for_deletion(), "pool contains no retired world objects")
	scene.teardown()
	t.ok(not InputRouter.playback_mode, "final teardown releases replay input ownership")
	for slot in cfg.player_count():
		t.equal(InputRouter.source_of(slot), InputRouter.Source.NONE, "final teardown releases slot sources")
	scene.queue_free()
	transport.queue_free()
	player.free()
	await host.get_tree().process_frame
