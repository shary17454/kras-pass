extends Node


func _ready() -> void:
	UserSettings.set_value("replay_capture", false)
	var cfg := MatchConfig.build("sabaq_sawarikh", ["sakhra", "fanoos", "ramla", "barq"], 0, 1, 9614)
	cfg.rounds = 1
	var scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var results := []
	scene.setup({"config": cfg, "on_finished": func(result): results.append(result)})
	print("PARTY RACE arena=", cfg.arena_id, " seed=", cfg.seed)
	for tick in 60 * 600:
		if not results.is_empty():
			break
		await get_tree().physics_frame
		if tick % 7200 == 0 and tick > 0:
			print("race progress ", tick / 60, "s laps=", scene.controller.lap, " checkpoints=", scene.controller._next_cp)
			for fighter in scene.ctx.fighters:
				print("slot=", fighter.slot, " pos=", fighter.global_position, " velocity=", fighter.velocity, " target=", scene.controller.next_checkpoint(fighter.slot))
	var passed := not results.is_empty()
	if passed:
		var result: MatchResult = results[0]
		for slot in cfg.players.size():
			passed = passed and int(result.detail(slot, "laps")) == 3
		print("finish duration=", result.duration, " rescue counts=", result.details)
	print("PARTY RACE: ", "PASS" if passed else "FAIL")
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
