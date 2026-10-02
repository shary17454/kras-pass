extends Node

func _ready() -> void:
	UserSettings.set_value("replay_capture", false)
	var seed_value := 9614
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	var cfg := MatchConfig.build("boss_colossus", ["sakhra", "fanoos", "ramla", "nabta"], 0, 3, seed_value)
	cfg.rounds = 1
	var scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var results := []
	scene.setup({"config": cfg, "on_finished": func(result): results.append(result)})
	for tick in 60 * 220:
		if not results.is_empty(): break
		await get_tree().physics_frame
		if tick > 0 and tick % 1800 == 0:
			print("COLOSSUS_AI time=", tick / 60, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores, " holes=", scene.controller._craters.size())
	var passed: bool = not results.is_empty() and scene.controller.boss_defeated
	print("COLOSSUS_AI seed=", cfg.seed, " difficulty=", cfg.players[0].ai_difficulty, " defeated=", scene.controller.boss_defeated, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores)
	print("COLOSSUS_AI: ", "PASS" if passed else "FAIL")
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if passed else 1)
