extends Node
## Presentation fixture only. Network behavior is tested by network-smoke.js.


func _ready() -> void:
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless":
		push_error("Online UI check requires a renderer and isolated --test-data-dir")
		get_tree().quit(1)
		return
	Loc.set_locale("ar")
	Net.online_available = true
	Net.room_code = "ABC234"
	Net.room_state = "lobby"
	Net.state = Net.State.LOBBY
	Net.mode = Net.Mode.ONLINE_HOST
	Net.is_host = true
	Net.local_peer_id = 1
	Net.lobby_config = {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 3, "bots": true, "difficulty": 1}
	Net.lobby_config["tournament"] = {"mode": "points", "target": 3, "rotation": "random_no_repeat",
		"points": [5, 3, 2, 1], "entries": [{"game": "ring_rumble", "arena": "vortex_ring"}, {"game": "ring_rumble", "arena": "storm_ring"}]}
	if "--goal-guard" in OS.get_cmdline_user_args():
		Net.lobby_config.game = "goal_guard"
		Net.lobby_config.arena = "quad_court"
		Net.lobby_config.tournament.entries = [{"game": "goal_guard", "arena": "quad_court"}]
	for i in 4:
		Net.peers[i + 1] = {"id": i + 1, "slot": i, "name": "P%d" % (i + 1), "ready": true, "connected": true, "character": i}
	for dimensions in [Vector2i(1920, 1080), Vector2i(1080, 1920)]:
		Net.tournament = {}
		get_window().size = dimensions
		get_window().content_scale_size = dimensions
		var screen := load("res://src/ui/screens/online_screen.gd").new() as Screen
		add_child(screen)
		screen.setup({})
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var game_select := screen.find_child("OnlineGameSelect", true, false) as OptionButton
		var arena_select := screen.find_child("OnlineArenaSelect", true, false) as OptionButton
		if game_select == null or arena_select == null or game_select.item_count != Net.ONLINE_GAMES.size() \
				or Net.ONLINE_GAMES[game_select.selected] != Net.lobby_config.game \
				or arena_select.item_count != Net.ONLINE_ARENAS[Net.lobby_config.game].size():
			push_error("ONLINE_UI_FAIL=game/arena selection mismatch")
			get_tree().quit(1)
			return
		var path := "/tmp/kras-online-ui-%dx%d.png" % [dimensions.x, dimensions.y]
		get_viewport().get_texture().get_image().save_png(path)
		print("ONLINE_UI_SCREENSHOT=" + path)
		screen.queue_free()
		await get_tree().process_frame
		var cfg := MatchConfig.new()
		cfg.context = MatchConfig.Context.ONLINE
		cfg.minigame_id = Net.lobby_config.game
		cfg.arena_id = Net.lobby_config.arena
		for i in 4:
			var player := PlayerConfig.new()
			player.slot = i
			player.character_id = Registry.characters()[i].id
			player.display_name_override = "P%d" % (i + 1)
			player.is_human = i == 0
			cfg.players.append(player)
		var result := MatchResult.new()
		result.minigame_id = cfg.minigame_id
		result.arena_id = cfg.arena_id
		result.scores = [8, 6, 4, 2]
		result.places = [1, 2, 3, 4]
		Net.tournament = {"mode": "points", "points": [15, 9, 6, 3], "cups": [3, 0, 0, 0], "complete": true, "champions": [0]}
		var results := load("res://src/ui/screens/results_screen.gd").new() as Screen
		add_child(results)
		results.setup({"config": cfg, "result": result})
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var table := results.find_child("RoundStandings", true, false) as GridContainer
		if table == null or table.get_child_count() != 4 or table.size.y < 100:
			push_error("ONLINE_UI_FAIL=missing round standings")
			get_tree().quit(1)
			return
		path = "/tmp/kras-online-results-%dx%d.png" % [dimensions.x, dimensions.y]
		get_viewport().get_texture().get_image().save_png(path)
		print("ONLINE_UI_SCREENSHOT=" + path)
		results.queue_free()
		await get_tree().process_frame
	Net.leave()
	get_tree().quit()
