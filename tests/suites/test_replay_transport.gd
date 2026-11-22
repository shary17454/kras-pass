extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay transport responsive layout")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		UserSettings.set_value("text_scale", 1.4)
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			window.size = resolution
			var screen: Control = load("res://src/ui/screens/replay_player.gd").new()
			var recording := ReplayData.new()
			recording.minigame_id = "sweeper_storm"
			for kind in ["narrow_win", "late_swing", "comeback", "early_exit", "multi_knockout", "big_hit"]:
				recording.highlights.append({"tick": 0, "kind": kind, "slot": 0, "detail": ""})
			screen.replay = recording
			var column := VBoxContainer.new()
			column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.add_child(column)
			var panel: Control = screen._transport()
			column.add_child(panel)
			for frame in 8:
				await host.get_tree().process_frame
			var viewport := host.get_viewport().get_visible_rect()
			t.ok(viewport.encloses(panel.get_global_rect()), "%s %s transport remains in viewport" % [locale, resolution])
			var buttons := _buttons(panel)
			t.equal(buttons.size(), 12, "all transport and highlight controls remain available")
			for button in buttons:
				t.ok(panel.get_global_rect().encloses(button.get_global_rect()), "control stays inside transport: " + button.text)
				for other in buttons:
					if other != button:
						t.ok(not button.get_global_rect().intersects(other.get_global_rect()), "controls do not overlap")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var output := SaveSystem.storage_root.path_join("replay-transport-screenshots")
				DirAccess.make_dir_recursive_absolute(output)
				var filename := "%s-%dx%d.png" % [locale, resolution.x, resolution.y]
				t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save rendered transport")
			column.queue_free()
			screen.free()
			await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)
	await _pause_lifecycle(t, host)


func _pause_lifecycle(t: TestHarness, host: Node) -> void:
	t.suite("replay transport pause lifecycle P2")
	var errors_before := Log.error_count()
	var cfg := MatchConfig.build("zone_hold", ["nabta", "sakhra"], 0, 1, 22022)
	cfg.duration_override = 1.0
	cfg.rounds = 2
	cfg.sudden_death = false
	var packets: Array = []
	for tick in 122:
		var packet := PackedByteArray()
		for slot in cfg.player_count():
			packet.append_array(InputFrame.new().encode())
		packets.append(packet)
	var recording := ReplayData.from_match(cfg, packets, {}, {}, null)
	var phases := [MatchPhase.P.INTRO, MatchPhase.P.INSTRUCTIONS, MatchPhase.P.COUNTDOWN,
		MatchPhase.P.PLAYING, MatchPhase.P.FINISH, MatchPhase.P.NEXT_ROUND]
	var successors := [MatchPhase.P.INSTRUCTIONS, MatchPhase.P.COUNTDOWN, MatchPhase.P.PLAYING,
		MatchPhase.P.FINISH, MatchPhase.P.NEXT_ROUND, MatchPhase.P.INSTRUCTIONS]
	var delta := 1.0 / 60.0
	for index in phases.size():
		var target: int = phases[index]
		var label := MatchPhase.name_of(target).to_upper()
		t.test(label + " freezes its clock and lifecycle, then resumes without catch-up")
		var scene = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.set_physics_process(false)
		scene.setup({"replay": recording})
		# Reach each phase through the real lifecycle, without seek or phase assignment.
		for step in 1200:
			if scene.phase == target or scene.phase == MatchPhase.P.DONE:
				break
			scene._physics_process(delta)
		t.equal(scene.phase, target, label + " fixture reached through normal playback")
		var events: Array = []
		var on_phase := func(value): events.append(["phase", value])
		var on_countdown := func(value): events.append(["countdown", value])
		var on_round := func(value): events.append(["round", value.round_index])
		var on_progress := func(value, _total): events.append(["progress", value])
		var on_finished := func(): events.append(["finished"])
		EventBus.match_phase_changed.connect(on_phase)
		EventBus.countdown_tick.connect(on_countdown)
		EventBus.round_finished.connect(on_round)
		scene.playback_progress.connect(on_progress)
		scene.playback_finished.connect(on_finished)
		var timer: float = scene._phase_timer
		var duration: float = scene._phase_duration
		var countdown: int = scene._countdown_value
		var round_index: int = scene._round_index
		var results: int = scene._round_results.size()
		var tick: int = scene.playback_tick
		var simulation_tick: int = scene._tick_index
		var time_left: float = scene.ctx.time_left
		var elapsed: float = scene._round_elapsed
		var speed_accum: float = scene._speed_accum
		scene.pb_toggle_pause()
		t.ok(scene.playback_paused, label + " transport pause enabled")
		scene._physics_process(delta)
		t.near(scene._phase_timer, timer, 0.000001, label + " first paused step preserves phase timer")
		# Exceed the entire phase duration so a live-only guard cannot pass.
		var paused_steps := maxi(240, ceili(timer / delta) + 60)
		for step in paused_steps:
			scene._physics_process(delta)
		t.equal(scene.phase, target, label + " paused phase does not advance")
		t.equal(scene.ctx.phase, target, label + " paused context phase does not advance")
		t.near(scene._phase_timer, timer, 0.000001, label + " paused phase timer is frozen")
		t.equal(scene._phase_duration, duration, label + " phase duration stays unchanged")
		t.equal(scene._countdown_value, countdown, label + " paused countdown is frozen")
		t.equal(scene._round_index, round_index, label + " paused round index is frozen")
		t.equal(scene._round_results.size(), results, label + " paused round results are frozen")
		t.equal(scene.playback_tick, tick, label + " paused recording cursor is frozen")
		t.equal(scene._tick_index, simulation_tick, label + " paused simulation cursor is frozen")
		t.equal(scene.ctx.time_left, time_left, label + " paused round clock is frozen")
		t.equal(scene._round_elapsed, elapsed, label + " paused elapsed play time is frozen")
		t.equal(scene._speed_accum, speed_accum, label + " paused speed accumulator is frozen")
		t.empty(events, label + " pause emits no lifecycle or playback events")

		scene.pb_toggle_pause()
		t.ok(not scene.playback_paused, label + " transport resume enabled")
		scene._physics_process(delta)
		t.equal(scene.phase, target, label + " first resumed step stays in original phase")
		if target == MatchPhase.P.PLAYING:
			t.near(scene.ctx.time_left, time_left - delta, 0.000001, label + " resumes exactly one clock step")
			t.equal(scene.playback_tick, tick + 1, label + " resumes exactly one recorded input")
		else:
			t.near(scene._phase_timer, timer - delta, 0.000001, label + " resumes from remaining timer without catch-up")
			t.equal(scene.playback_tick, tick, label + " resume consumes no non-live input")
		for step in 1200:
			if scene.phase != target:
				break
			scene._physics_process(delta)
		t.equal(scene.phase, successors[index], label + " resumes the correct lifecycle edge")
		t.equal(scene.ctx.phase, scene.phase, label + " resumed context agrees with runtime")
		var next_round := round_index + (1 if target == MatchPhase.P.NEXT_ROUND else 0)
		var next_results := results + (1 if target == MatchPhase.P.FINISH else 0)
		t.equal(scene._round_index, next_round, label + " resumes without skipping rounds")
		t.equal(scene._round_results.size(), next_results, label + " completes each round exactly once")
		EventBus.match_phase_changed.disconnect(on_phase)
		EventBus.countdown_tick.disconnect(on_countdown)
		EventBus.round_finished.disconnect(on_round)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	t.equal(Log.error_count(), errors_before, "pause lifecycle logs no runtime errors")


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result
