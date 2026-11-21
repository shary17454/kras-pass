extends "res://tools/balance_sim.gd"


func _play(cfg: MatchConfig) -> MatchResult:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var captured: Array = []
	scene.setup({"config": cfg, "on_finished": func(result): captured.append(result)})
	var peaks: Array = []
	peaks.resize(cfg.players.size())
	peaks.fill(-INF)
	var samples: Array = []
	var guard := 0
	while captured.is_empty() and guard < _tick_budget(cfg):
		await get_tree().physics_frame
		guard += 1
		if not MatchPhase.is_live(scene.phase):
			continue
		var states: Array = []
		for slot in scene.ctx.player_count():
			var fighter: Fighter = scene.ctx.fighter(slot)
			peaks[slot] = maxf(peaks[slot], fighter.global_position.y)
			if guard % 30 != 0:
				continue
			var brain = scene._brains[slot]
			states.append({"slot": slot, "position": str(fighter.global_position),
				"floor": fighter.is_on_floor(), "alive": scene.ctx.is_alive(slot),
				"target": str(brain._ledge_target) if brain != null else "human",
				"prepare": brain._prepare_jump if brain != null else false})
		if not states.is_empty():
			samples.append({"time": scene._round_elapsed, "water": scene.arena.water_level(), "states": states})
	var result: MatchResult = captured[0] if not captured.is_empty() else null
	print("TIDE_TRACE=" + JSON.stringify({"seed": cfg.seed, "peaks": peaks,
		"scores": Array(result.scores) if result != null else [],
		"draw": result.is_draw() if result != null else false, "samples": samples}))
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	return result
