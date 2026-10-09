extends Node
## Both orientations, optionally every declared game/arena pairing. Rendering
## smoke only, not physical-player, performance or balance certification.

var _rows: Array = []
var _failures: Array[String] = []


static func parse_human_count(value: String) -> int:
	if not value.is_valid_int():
		return -1
	var count := int(value)
	return count if count >= 1 and count <= 4 else -1


static func capture_cases(games: Array, selected: PackedStringArray, all_arenas: bool,
		selected_arenas: PackedStringArray = PackedStringArray()) -> Array:
	var cases: Array = []
	for game in games:
		if not selected.is_empty() and not game.id in selected:
			continue
		var arenas: PackedStringArray = game.arena_ids
		if not all_arenas and arenas.size() > 1:
			arenas = PackedStringArray([arenas[0]])
		for arena_id in arenas:
			if not selected_arenas.is_empty() and not arena_id in selected_arenas:
				continue
			cases.append({"game": game, "arena": arena_id})
	return cases


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Stage-zero visual QA needs a real renderer")
		get_tree().quit(1)
		return
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("announcer_enabled", false)
	UserSettings.set_value("touch_controls", "on")
	var language := "ar"
	var play_seconds := 0.0
	var human_count := 1
	var all_arenas := false
	var selected := PackedStringArray()
	var selected_arenas := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument == "--all-arenas":
			all_arenas = true
		elif argument.begins_with("--games="):
			selected = argument.trim_prefix("--games=").split(",", false)
		elif argument.begins_with("--arenas="):
			selected_arenas = argument.trim_prefix("--arenas=").split(",", false)
		elif argument.begins_with("--locale="):
			language = argument.trim_prefix("--locale=")
		elif argument.begins_with("--humans="):
			human_count = parse_human_count(argument.trim_prefix("--humans="))
			if human_count < 0:
				push_error("Visual QA humans must be an integer from one to four")
				get_tree().quit(2)
				return
		elif argument.begins_with("--play-seconds="):
			var value := argument.trim_prefix("--play-seconds=")
			if not value.is_valid_float() or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 10.0:
				push_error("Visual play seconds must be finite and between zero and ten")
				get_tree().quit(2)
				return
			play_seconds = float(value)
	if not language in Loc.SUPPORTED:
		push_error("Unsupported visual QA locale: " + language)
		get_tree().quit(1)
		return
	for id in selected:
		if Registry.minigame(id) == null:
			push_error("Unknown visual QA game: " + id)
			get_tree().quit(1)
			return
	for id in selected_arenas:
		if Registry.arena(id) == null:
			push_error("Unknown visual QA arena: " + id)
			get_tree().quit(1)
			return
	Loc.set_locale(language)
	var cases := capture_cases(Registry.all_minigames(), selected, all_arenas, selected_arenas)
	if cases.is_empty():
		push_error("Visual QA selection contains no game/arena pairs")
		get_tree().quit(2)
		return
	var output := SaveSystem.storage_root.path_join("screenshots")
	var initial_errors := Log.error_count()
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
		get_window().size = resolution
		var orientation := "portrait" if resolution.x < resolution.y else "landscape"
		for capture in cases:
			var game: MiniGameDef = capture.game
			var errors_before := Log.error_count()
			var cfg := MatchConfig.build(game.id, ["nabta", "sakhra", "fanoos", "ramla"], human_count, 1, 250925)
			cfg.arena_id = capture.arena
			for player in cfg.players:
				if player.is_human:
					player.device_type = 2
			cfg.rounds = 1
			await SceneRouter.go_to("match", {"config": cfg}, false, 0)
			var scene: Node = SceneRouter.current_node
			for i in 8:
				await get_tree().process_frame
			# Skip only presentation waiting, retaining each legal lifecycle edge.
			if scene.phase == MatchPhase.P.INTRO:
				scene._set_phase(MatchPhase.P.INSTRUCTIONS)
			if scene.phase == MatchPhase.P.INSTRUCTIONS:
				scene._set_phase(MatchPhase.P.COUNTDOWN)
			if scene.phase == MatchPhase.P.COUNTDOWN:
				scene._set_phase(MatchPhase.P.PLAYING)
			scene.camera._intro_left = 0.0
			for i in 24:
				await get_tree().process_frame
			if play_seconds > 0.0:
				await get_tree().create_timer(play_seconds).timeout
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var label := game.id + ("-" + cfg.arena_id if all_arenas else "")
			var file := output.path_join(label + "-" + orientation + ".png")
			var colors := {}
			for x in range(0, image.get_width(), 11):
				for y in range(0, image.get_height(), 11):
					colors[image.get_pixel(x, y).to_html()] = true
			var success: bool = image.save_png(file) == OK and colors.size() >= 15 \
				and scene.ctx.fighters.size() == 4 and Log.error_count() == errors_before \
				and scene.touch_sources.size() == human_count and not scene._paused \
				and scene._pause_menu == null and MatchPhase.is_live(scene.phase)
			success = success and scene.ctx.arena_def.id == cfg.arena_id
			var control_bounds_valid := true
			var touch_slots: Array[int] = []
			for source in scene.touch_sources:
				touch_slots.append(source.slot)
				for control in source.control_rects():
					control_bounds_valid = control_bounds_valid and source.get_global_rect().grow(1.0).encloses(control)
			success = success and control_bounds_valid and touch_slots == cfg.human_slots()
			var objective: Label = scene.hud._hint_label
			var objective_visible := objective.is_visible_in_tree()
			var objective_matches := objective.text == Loc.t(game.desc_key)
			var objective_bounds_valid := true
			if objective_visible:
				var bounds := objective.get_global_rect()
				objective_bounds_valid = get_viewport().get_visible_rect().grow(1.0).encloses(bounds)
				for chip in scene.hud._chips:
					if chip.root.is_visible_in_tree():
						objective_bounds_valid = objective_bounds_valid and not bounds.intersects(chip.root.get_global_rect())
				for source in scene.touch_sources:
					for control in source.control_rects():
						objective_bounds_valid = objective_bounds_valid and not bounds.intersects(control)
			success = success and objective_matches and objective_bounds_valid
			var hud_bottom: float = scene.hud.occupied_top()
			if game.id.begins_with("boss_") and resolution.x < resolution.y:
				success = success and hud_bottom < image.get_height() * 0.35
			_rows.append({"id": game.id, "arena": cfg.arena_id, "orientation": orientation,
				"actual_arena": scene.ctx.arena_def.id,
				"image": file, "nonblank_colors": colors.size(), "hud_bottom": hud_bottom, "passed": success,
				"requested_play_seconds": play_seconds, "phase": scene.phase,
				"paused": scene._paused, "pause_menu_present": scene._pause_menu != null,
				"time_left": scene.ctx.time_left, "alive_players": scene.ctx.alive_count(),
				"human_count": human_count, "touch_slots": touch_slots,
				"control_bounds_valid": control_bounds_valid,
				"objective_key": game.desc_key, "objective_text": objective.text,
				"objective_visible": objective_visible, "objective_matches": objective_matches,
				"objective_bounds_valid": objective_bounds_valid})
			if game.id == "rising_tide":
				var observations: Array = []
				for slot in scene._brains.size():
					var brain = scene._brains[slot]
					if brain == null:
						continue
					var water = scene.arena._water
					var history: Array = brain._object_history.get(water.get_instance_id(), [])
					observations.append({"slot": slot, "visible": brain.can_observe(water),
						"history_entries": history.size(), "water_level": scene.arena.water_level()})
				_rows[-1]["water_observation"] = observations
			if not success:
				_failures.append(label + "/" + orientation)
			print("STAGE ZERO VISUAL %s/%s: %s" % [label, orientation, "PASS" if success else "FAIL"])
			await SceneRouter.go_to("main_menu", {}, false, 0)
			await get_tree().process_frame
			if Log.error_count() != errors_before:
				_rows[-1]["passed"] = false
				_failures.append(label + "/" + orientation + "/cleanup")
	if Log.error_count() != initial_errors and _failures.is_empty():
		_failures.append("runtime errors outside capture window")
	var report := FileAccess.open(SaveSystem.storage_root.path_join("visual-report.json"), FileAccess.WRITE)
	if report == null:
		_failures.append("report write failed")
	else:
		report.store_string(JSON.stringify({"shots": _rows, "failures": _failures,
			"all_arenas": all_arenas, "expected_captures": cases.size() * 2,
			"selected_arenas": selected_arenas,
			"scope": "%d game/arena pairs, %s, %s, %d human slots + %d AI, 2 orientations, %.1f additional play seconds; smoke only, not physical humans" % [
				cases.size(), "all declared arenas" if all_arenas else "default arenas", language, human_count, 4 - human_count, play_seconds]}, "  "))
		report.close()
	print("STAGE ZERO VISUAL: %d captures, %d failures" % [_rows.size(), _failures.size()])
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if _failures.is_empty() else 1)
