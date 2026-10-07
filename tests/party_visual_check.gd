extends Node

var _errors: Array[String] = []


func _ready() -> void:
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless":
		push_error("Party visual QA requires a renderer and isolated --test-data-dir")
		get_tree().quit(1)
		return
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
				await SceneRouter.go_to(id, {}, false, 0)
				await _settle()
				_scan(SceneRouter.current_node, orientation + "/" + locale + "/" + id)
				_capture("%s-%s-%s" % [orientation, locale, id])
			SaveSystem._read_only_paths[SaveSystem._path(SaveSystem.PROFILE)] = true
			await SceneRouter.go_to("main_menu", {}, false, 0)
			await _settle()
			_scan(SceneRouter.current_node, orientation + "/" + locale + "/save-compatibility")
			var notice := SceneRouter.current_node.find_child("SaveCompatibilityNotice", true, false) as Label
			if notice == null or notice.text != Loc.t("save.newer_version"):
				_errors.append("newer-save warning missing or not localized")
			elif not get_viewport().get_visible_rect().encloses(notice.get_global_rect()):
				_errors.append("newer-save warning is outside viewport")
			_capture("%s-%s-save-compatibility" % [orientation, locale])
			SaveSystem._read_only_paths.erase(SaveSystem._path(SaveSystem.PROFILE))
			var s := TournamentSession.from_preset("long", PartyRoster.last_players(), 22)
			await SceneRouter.go_to("standings", {"session": s}, false, 0)
			await _settle()
			_scan(SceneRouter.current_node, orientation + "/" + locale + "/standings")
			_check_standings_layout(orientation, false)
			_capture("%s-%s-standings" % [orientation, locale])
			var final := TournamentSession.new()
			final.setup(PartyRoster.last_players(), ["ring_rumble"] as Array[String], 43)
			final.index = 1
			final.points = [5, 3, 2, 1]
			final.resolved_champion = 0
			final.performance[0] = {"knockouts": 4, "collected": 8}
			final.performance[1] = {"falls": 3}
			await SceneRouter.go_to("standings", {"session": final}, false, 0)
			await _settle()
			_scan(SceneRouter.current_node, orientation + "/" + locale + "/podium")
			_check_standings_layout(orientation, true)
			_capture("%s-%s-podium" % [orientation, locale])
		Loc.set_locale("ar")
		var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 742)
		for p in cfg.players:
			p.device_type = 2
		await SceneRouter.start_match(cfg)
		if not _match_loaded("ring_rumble"):
			get_tree().quit(1)
			return
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
		await SceneRouter.go_to("main_menu", {}, false, 0)
		await _settle()
		for game_id in ["tank_arena", "sabaq_sawarikh"]:
			var shared := MatchConfig.build(game_id, ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 188)
			for p in shared.players:
				p.device_type = 2
			await SceneRouter.start_match(shared)
			if not _match_loaded(game_id):
				get_tree().quit(1)
				return
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
			await SceneRouter.go_to("main_menu", {}, false, 0)
			await _settle()
	if SceneRouter.current_node != null:
		SceneRouter.current_node.queue_free()
		SceneRouter.current_node = null
	await _settle()
	for error in _errors:
		print("FAIL: " + error)
	print("PARTY VISUAL CHECK: %d failures" % _errors.size())
	get_tree().quit(0 if _errors.is_empty() else 1)


func _match_loaded(game_id: String) -> bool:
	var scene: Node = SceneRouter.current_node
	if SceneRouter.current_id != "match" or not is_instance_valid(scene) or not scene.has_method("_set_phase"):
		push_error("Party visual QA did not load match: " + game_id)
		return false
	if scene.ctx == null or scene.ctx.config.minigame_id != game_id:
		push_error("Party visual QA loaded the wrong match: " + game_id)
		return false
	return true


func _check_standings_layout(orientation: String, champion: bool) -> void:
	var screen: Node = SceneRouter.current_node
	var rows := screen.find_child("StandingsRows", true, false) as VBoxContainer
	var actions := screen.find_child("StandingsActions", true, false) as Control
	if rows == null or rows.get_child_count() != 4:
		_errors.append(orientation + ": standings must retain all four ranks")
		return
	if rows.get_parent() is ScrollContainer:
		_errors.append(orientation + ": standings have a nested scrolling region")
	if actions == null or actions.get_parent() == screen.body:
		_errors.append(orientation + ": standings actions are not pinned outside scrolling content")
		return
	var visible := get_viewport().get_visible_rect()
	if not visible.encloses(actions.get_global_rect()):
		_errors.append(orientation + ": standings actions are outside the viewport")
	if champion:
		var columns := screen.find_child("ChampionColumns", true, false) as BoxContainer
		if columns == null or columns.vertical != (orientation == "portrait"):
			_errors.append(orientation + ": champion layout does not adapt to orientation")
		if orientation == "landscape":
			var scroll := screen.body.get_parent() as ScrollContainer
			for row in rows.get_children():
				if not scroll.get_global_rect().encloses(row.get_global_rect()):
					_errors.append("landscape: complete standings row is clipped")


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
