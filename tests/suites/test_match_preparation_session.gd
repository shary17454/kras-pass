extends RefCounted

class SessionRouter extends "res://src/core/scene_router.gd":
	var mutation := ""
	var reached_swap := false
	func _fade(target: float, duration: float) -> void:
		if target == 1.0 and mutation == "fade_epoch":
			Net.epoch += 1
		await super._fade(target, duration)
	func _prepare_match(_job: Node, _config: MatchConfig) -> bool:
		await get_tree().process_frame
		match mutation:
			"epoch": Net.epoch += 1
			"reset": Net.mode = Net.Mode.LOCAL; Net.state = Net.State.OFFLINE
			"disconnect": Net.state = Net.State.DISCONNECTED
			"room": Net.room_code = "OTHER1"
			"results": Net.room_state = "results"
			"seed": Net.match_data.seed = 12
			"game": Net.match_data.config.game = "goal_guard"
			"arena": Net.match_data.config.arena = "other"
			"missing": Net.match_data.clear()
			"malformed": Net.match_data.config = []
			"lobby": Net.state = Net.State.LOBBY
			"playing": Net.room_state = "playing"
		return true
	func _swap(_id: String, _args: Dictionary) -> bool:
		reached_swap = true
		return false


func run(t: TestHarness, host: Node) -> void:
	t.suite("online session integrity during resource preparation")
	var saved := [Net.mode, Net.state, Net.room_state, Net.room_code, Net.epoch, Net.match_data.duplicate(true)]
	var config := MatchConfig.build("ring_rumble", ["nabta"], 1, 1, 11)
	config.context = MatchConfig.Context.ONLINE
	for mutation in ["epoch", "fade_epoch", "reset", "disconnect", "room", "results", "seed", "game", "arena", "missing", "malformed", "lobby", "playing", ""]:
		Net.mode = Net.Mode.ONLINE_HOST
		Net.state = Net.State.IN_MATCH
		Net.room_state = "loading"
		Net.room_code = "START1"
		Net.epoch = 11
		Net.match_data = {"seed": 11, "config": {"game": config.minigame_id, "arena": config.arena_id}}
		var router := SessionRouter.new()
		router.mutation = mutation
		host.add_child(router)
		var previous := Control.new()
		router.holder.add_child(previous)
		router.current_node = previous
		router.current_id = "online"
		await router.go_to("match", {"config": config}, true, 0.0)
		t.equal(router.reached_swap, mutation in ["", "playing"], "only the original active online session reaches setup: " + mutation)
		t.ok(router.current_node == previous, "rejected or fixture-failed swap preserves the online screen")
		t.ok(not router._busy and not router.loading_progress.visible, "session change does not lock navigation")
		router.queue_free()
		await host.get_tree().process_frame
	Net.mode = saved[0]
	Net.state = saved[1]
	Net.room_state = saved[2]
	Net.room_code = saved[3]
	Net.epoch = saved[4]
	Net.match_data = saved[5]
