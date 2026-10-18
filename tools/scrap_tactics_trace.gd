extends Node
## Read-only telemetry over the same paired configurations as balance_sim.


func _ready() -> void:
	var policy = preload("res://tools/balance_sim.gd").new()
	if not policy._storage_is_isolated(SaveSystem.storage_root):
		policy.free()
		push_error("Scrap trace requires isolated --test-data-dir")
		get_tree().quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed-offset="):
			if not policy._set_seed_offset(argument.trim_prefix("--seed-offset=")):
				policy.free()
				push_error("Invalid trace seed offset")
				get_tree().quit(2)
				return
	policy.runs = 24
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("show_control_hints", false)
	await get_tree().process_frame
	var definition: MiniGameDef = Registry.minigame("scrap_karts")
	var failures := 0
	for sample in policy._difficulty_runs():
		var config: MatchConfig = policy._difficulty_configuration(definition, sample)
		var scene = load("res://src/match/match_scene.gd").new()
		add_child(scene)
		var results := []
		scene.setup({"config": config, "on_finished": func(result): results.append(result)})
		var telemetry: Array[Dictionary] = []
		for slot in 4:
			telemetry.append({"slot": slot, "tier": config.players[slot].ai_difficulty,
				"alive_ticks": 0, "backoff_ticks": 0, "edge_ticks": 0,
				"dash_ticks": 0, "health_lost": 0.0, "last_health": 100.0,
				"death": "survived", "minimum_margin": INF})
		for tick in policy._tick_budget(config):
			if not results.is_empty():
				break
			await get_tree().physics_frame
			if scene.phase != MatchPhase.P.PLAYING:
				continue
			for slot in 4:
				var row: Dictionary = telemetry[slot]
				var health: float = scene.controller.health[slot]
				row.health_lost += maxf(0.0, float(row.last_health) - health)
				row.last_health = health
				if not scene.ctx.is_alive(slot):
					row.death = "ram" if scene.controller.wrecks[slot] > 0 else "fall"
					continue
				var fighter: Fighter = scene.ctx.fighter(slot)
				var margin: float = scene.arena.edge_distance(fighter.global_position)
				row.minimum_margin = minf(float(row.minimum_margin), margin)
				row.alive_ticks += 1
				row.backoff_ticks += int(scene._brains[slot]._state == "backoff")
				row.edge_ticks += int(margin < lerpf(3.5, 9.0, clampf(fighter.speed_ratio(), 0.0, 1.0)))
				row.dash_ticks += int(fighter.is_dashing())
		if results.is_empty():
			failures += 1
		else:
			for row in telemetry:
				var slot: int = row.slot
				var final_health: float = scene.controller.health[slot]
				row.health_lost += maxf(0.0, float(row.last_health) - final_health)
				if not scene.ctx.is_alive(slot):
					row.death = "ram" if scene.controller.wrecks[slot] > 0 else "fall"
				row.erase("last_health")
			print("SCRAP_TRACE=" + JSON.stringify({"sample": sample, "seed": config.seed,
				"character": config.players[0].character_id, "scores": Array(results[0].scores),
				"places": Array(results[0].places), "finished_naturally": results[0].finished_naturally,
				"duration": results[0].duration, "players": telemetry}))
		scene.teardown()
		scene.queue_free()
		await get_tree().process_frame
	policy.free()
	AudioManager.shutdown()
	await get_tree().process_frame
	print("SCRAP_TRACE_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
