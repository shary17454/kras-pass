extends Node

func _ready() -> void:
	UserSettings.set_value("replay_capture", false)
	var seed_value := 9614
	var game_id := "boss_colossus"
	var trace := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--game="):
			game_id = argument.trim_prefix("--game=")
		elif argument == "--trace":
			trace = true
	if game_id not in ["boss_colossus", "boss_forge", "boss_dreadnought", "boss_sovereign"]:
		push_error("BOSS_AI: unsupported game")
		get_tree().quit(1)
		return
	var label := "COLOSSUS_AI" if game_id == "boss_colossus" else "BOSS_AI"
	var cfg := MatchConfig.build(game_id, ["sakhra", "fanoos", "ramla", "nabta"], 0, 3, seed_value)
	cfg.rounds = 1
	var scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var results := []
	scene.setup({"config": cfg, "on_finished": func(result): results.append(result)})
	var previous_exposure := 0.0
	for tick in 60 * 220:
		if not results.is_empty(): break
		await get_tree().physics_frame
		if trace and game_id == "boss_colossus":
			var exposure: float = scene.controller._exposed
			if exposure > previous_exposure + 0.01:
				print("COLOSSUS_TRACE time=", tick / 60.0, " health=", scene.controller.boss_health, " fist=", scene.controller._fist.global_position)
				for fighter in scene.ctx.fighters:
					var plan: Dictionary = scene.controller.attack_plan(fighter.global_position)
					var clear: bool = not plan.is_empty() and scene.arena._crater_floor.path_clear(fighter.global_position - scene.arena.global_position, plan.target - scene.arena.global_position)
					print("COLOSSUS_TRACE slot=", fighter.slot, " position=", fighter.global_position, " velocity=", fighter.velocity, " path_clear=", clear, " plan=", plan)
			previous_exposure = exposure
		if tick > 0 and tick % 1800 == 0:
			print(label, " game=", game_id, " time=", tick / 60, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores)
	var passed: bool = not results.is_empty() and scene.controller.boss_defeated
	print(label, " game=", game_id, " seed=", cfg.seed, " difficulty=", cfg.players[0].ai_difficulty, " defeated=", scene.controller.boss_defeated, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores)
	print(label, ": ", "PASS" if passed else "FAIL")
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if passed else 1)
