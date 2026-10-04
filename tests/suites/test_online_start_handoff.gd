extends RefCounted

class LobbyScreen extends "res://src/ui/screens/online_screen.gd":
	var launched: Array[MatchConfig] = []
	func _launch_match(config: MatchConfig) -> void:
		launched.append(config)


func run(t: TestHarness, host: Node) -> void:
	t.suite("online start handoff after loading")
	var saved_net := [Net.mode, Net.state, Net.room_state, Net.room_code, Net.epoch,
		Net.match_data.duplicate(true), Net.online_available]
	var saved_router := [SceneRouter._busy, SceneRouter.current_node, SceneRouter.current_id]
	var screen := LobbyScreen.new()
	host.add_child(screen)
	Net.online_available = false
	screen.setup({})
	SceneRouter.current_node = screen
	SceneRouter.current_id = "online"
	SceneRouter._busy = true
	var config := MatchConfig.build("ring_rumble", ["fanoos"], 1, 1, 11)
	config.context = MatchConfig.Context.ONLINE
	Net.mode = Net.Mode.ONLINE_HOST
	Net.state = Net.State.IN_MATCH
	Net.room_state = "loading"
	Net.room_code = "START1"
	Net.epoch = 11
	Net.match_data = {"seed": 11, "config": {"game": config.minigame_id, "arena": config.arena_id}}
	Net.match_start_requested.emit(config)
	t.equal(screen.launched.size(), 0, "a busy transition does not launch concurrently")
	SceneRouter._busy = false
	SceneRouter.transition_finished.emit()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	t.equal(screen.launched.size(), 1, "the current start request survives a busy transition")
	SceneRouter.transition_finished.emit()
	await host.get_tree().process_frame
	t.equal(screen.launched.size(), 1, "later transitions do not launch the consumed request twice")
	SceneRouter._busy = true
	Net.match_start_requested.emit(config)
	var newer := MatchConfig.build("ring_rumble", ["fanoos"], 1, 1, 22)
	newer.context = MatchConfig.Context.ONLINE
	_set_session(newer, 22)
	Net.match_start_requested.emit(newer)
	SceneRouter._busy = false
	SceneRouter.transition_finished.emit()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	t.equal(screen.launched.size(), 2, "multiple queued starts coalesce to one launch")
	t.ok(screen.launched.back() == newer, "only the newest server request launches")
	for mutation in ["epoch", "room", "disconnect", "local", "results", "lobby", "seed", "game", "arena", "missing", "screen", "null", "local_config"]:
		_set_session(config, 11)
		SceneRouter.current_id = "online"
		SceneRouter._busy = true
		if mutation == "null":
			Net.match_start_requested.emit(null)
		elif mutation == "local_config":
			var local := MatchConfig.build("ring_rumble", ["fanoos"], 1, 1, 11)
			Net.match_start_requested.emit(local)
		else:
			Net.match_start_requested.emit(config)
		match mutation:
			"epoch": Net.epoch = 12
			"room": Net.room_code = "OTHER1"
			"disconnect": Net.state = Net.State.DISCONNECTED
			"local": Net.mode = Net.Mode.LOCAL
			"results": Net.room_state = "results"
			"lobby": Net.state = Net.State.LOBBY
			"seed": Net.match_data.seed = 12
			"game": Net.match_data.config.game = "goal_guard"
			"arena": Net.match_data.config.arena = "other"
			"missing": Net.match_data.clear()
			"screen": SceneRouter.current_id = "main_menu"
		SceneRouter._busy = false
		SceneRouter.transition_finished.emit()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		t.equal(screen.launched.size(), 2, "stale or unrelated request is discarded: " + mutation)
		t.ok(screen._pending_match == null, "discarded request does not remain queued: " + mutation)
	_set_session(config, 11)
	SceneRouter.current_id = "online"
	SceneRouter._busy = true
	Net.match_start_requested.emit(config)
	SceneRouter.current_node = host
	SceneRouter._busy = false
	SceneRouter.transition_finished.emit()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	t.equal(screen.launched.size(), 2, "another screen instance cannot consume the queued start")
	t.ok(screen._pending_match == null, "navigation away discards the queued start")
	SceneRouter._busy = saved_router[0]
	SceneRouter.current_node = saved_router[1]
	SceneRouter.current_id = saved_router[2]
	screen.queue_free()
	await host.get_tree().process_frame
	Net.mode = saved_net[0]
	Net.state = saved_net[1]
	Net.room_state = saved_net[2]
	Net.room_code = saved_net[3]
	Net.epoch = saved_net[4]
	Net.match_data = saved_net[5]
	Net.online_available = saved_net[6]


func _set_session(config: MatchConfig, generation: int) -> void:
	Net.mode = Net.Mode.ONLINE_HOST
	Net.state = Net.State.IN_MATCH
	Net.room_state = "loading"
	Net.room_code = "START1"
	Net.epoch = generation
	Net.match_data = {"seed": config.seed, "config": {"game": config.minigame_id, "arena": config.arena_id}}
