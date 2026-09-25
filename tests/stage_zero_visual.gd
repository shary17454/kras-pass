extends Node
## One default arena per catalogue entry, both orientations. This is a rendering
## smoke test, not certification of every map, player count or balance rule.

var _rows: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Stage-zero visual QA needs a real renderer")
		get_tree().quit(1)
		return
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("announcer_enabled", false)
	UserSettings.set_value("touch_controls", "on")
	Loc.set_locale("ar")
	var output := SaveSystem.storage_root.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
		get_window().size = resolution
		var orientation := "portrait" if resolution.x < resolution.y else "landscape"
		for game in Registry.all_minigames():
			var errors_before := Log.error_count()
			var cfg := MatchConfig.build(game.id, ["nabta", "sakhra", "fanoos", "ramla"], 1, 1, 250925)
			cfg.players[0].device_type = 2
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
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var file := output.path_join(game.id + "-" + orientation + ".png")
			var colors := {}
			for x in range(0, image.get_width(), 11):
				for y in range(0, image.get_height(), 11):
					colors[image.get_pixel(x, y).to_html()] = true
			var success: bool = image.save_png(file) == OK and colors.size() >= 15 \
				and scene.ctx.fighters.size() == 4 and Log.error_count() == errors_before
			_rows.append({"id": game.id, "arena": cfg.arena_id, "orientation": orientation,
				"image": file, "nonblank_colors": colors.size(), "passed": success})
			if not success:
				_failures.append(game.id + "/" + orientation)
			print("STAGE ZERO VISUAL %s/%s: %s" % [game.id, orientation, "PASS" if success else "FAIL"])
			await SceneRouter.go_to("main_menu", {}, false, 0)
			await get_tree().process_frame
	var report := FileAccess.open(SaveSystem.storage_root.path_join("visual-report.json"), FileAccess.WRITE)
	if report == null:
		_failures.append("report write failed")
	else:
		report.store_string(JSON.stringify({"shots": _rows, "failures": _failures,
			"scope": "39 games, default arena, Arabic, 1 human + 3 AI, 2 orientations; smoke only"}, "  "))
		report.close()
	print("STAGE ZERO VISUAL: %d captures, %d failures" % [_rows.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
