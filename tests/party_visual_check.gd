extends Node

var _errors: Array[String] = []


func _ready() -> void:
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("announcer_enabled", false)
	UserSettings.set_value("touch_controls", "on")
	for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
		get_window().size = resolution
		await _settle()
		var orientation := "portrait" if resolution.x < resolution.y else "landscape"
		for locale in ["ar", "en"]:
			Loc.set_locale(locale)
			for id in ["main_menu", "tournament", "playlist_builder", "local_play", "profile", "touch_layout", "settings", "stats"]:
				SceneRouter.go_to(id, {}, false, 0)
				await _settle()
				_scan(SceneRouter.current_node, orientation + "/" + locale + "/" + id)
				_capture("%s-%s-%s" % [orientation, locale, id])
			var s := TournamentSession.from_preset("long", PartyRoster.last_players(), 22)
			SceneRouter.go_to("standings", {"session": s}, false, 0)
			await _settle()
			_scan(SceneRouter.current_node, orientation + "/" + locale + "/standings")
			_capture("%s-%s-standings" % [orientation, locale])
			var final := TournamentSession.new()
			final.setup(PartyRoster.last_players(), ["ring_rumble"] as Array[String], 43)
			final.index = 1
			final.points = [5, 3, 2, 1]
			final.resolved_champion = 0
			final.performance[0] = {"knockouts": 4, "collected": 8}
			final.performance[1] = {"falls": 3}
			SceneRouter.go_to("standings", {"session": final}, false, 0)
			await _settle()
			_scan(SceneRouter.current_node, orientation + "/" + locale + "/podium")
			_capture("%s-%s-podium" % [orientation, locale])
		Loc.set_locale("ar")
		var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 742)
		for p in cfg.players:
			p.device_type = 2
		SceneRouter.start_match(cfg)
		await _settle()
		var scene: Node = SceneRouter.current_node
		if scene.phase == MatchPhase.P.INTRO:
			scene._set_phase(MatchPhase.P.INSTRUCTIONS)
		scene._set_phase(MatchPhase.P.COUNTDOWN)
		scene.camera._intro_left = 0.0
		await _settle()
		_capture(orientation + "-four-touch")
		if scene.hud._chips.size() != 4:
			_errors.append("four-player HUD is incomplete")
		for source in scene.touch_sources:
			if scene.hud._hint_label.get_global_rect().intersects(source.get_global_rect()):
				_errors.append(orientation + ": objective overlaps the touch regions")
		SceneRouter.go_to("main_menu", {}, false, 0)
		await _settle()
		for game_id in ["tank_arena", "sabaq_sawarikh"]:
			var shared := MatchConfig.build(game_id, ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 188)
			for p in shared.players:
				p.device_type = 2
			SceneRouter.start_match(shared)
			await _settle()
			var match_scene: Node = SceneRouter.current_node
			match_scene._set_phase(MatchPhase.P.INSTRUCTIONS)
			match_scene._set_phase(MatchPhase.P.COUNTDOWN)
			match_scene.camera._intro_left = 0.0
			await _settle()
			_capture(orientation + "-four-touch-" + game_id)
			var controls_top := TouchSource.party_region(get_viewport().get_visible_rect().size, 0, 4).position.y
			for fighter in match_scene.ctx.fighters:
				var pixel: Vector2 = match_scene.camera.unproject_position(fighter.global_position)
				if pixel.y <= match_scene.hud.occupied_top() or pixel.y >= controls_top:
					_errors.append(orientation + ": world player is hidden behind the HUD or controls")
			SceneRouter.go_to("main_menu", {}, false, 0)
			await _settle()
	if SceneRouter.current_node != null:
		SceneRouter.current_node.queue_free()
		SceneRouter.current_node = null
	await _settle()
	for error in _errors:
		print("FAIL: " + error)
	print("PARTY VISUAL CHECK: %d failures" % _errors.size())
	get_tree().quit(0 if _errors.is_empty() else 1)


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/kras-party-" + name + ".png")
	var colors := {}
	for x in range(0, image.get_width(), 7):
		for y in range(0, image.get_height(), 7):
			colors[image.get_pixel(x, y).to_html()] = true
	if colors.size() < 15:
		_errors.append(name + " appears blank")


func _scan(node: Node, label: String) -> void:
	if node == null:
		_errors.append(label + " did not load")
		return
	if node is Control and node.is_visible_in_tree() and node.size.x > 1:
		if node is Label and node.name == "PlayerName" and node.size.x < 80:
			_errors.append(label + ": player name column is too narrow to read")
		var rect: Rect2 = node.get_global_rect()
		var viewport := get_viewport().get_visible_rect()
		if rect.end.x > viewport.end.x + 2 or rect.position.x < -2:
			_errors.append("%s: %s overflows horizontally: %s" % [label, node.name, rect])
	for child in node.get_children():
		_scan(child, label)
