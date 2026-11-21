extends Node

func _ready() -> void:
	UserSettings.set_value("replay_capture", false)
	var seed_value := 9614
	var game_id := "boss_colossus"
	var trace := false
	var difficulty := 3
	var characters := ["sakhra", "fanoos", "ramla", "nabta"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--game="):
			game_id = argument.trim_prefix("--game=")
		elif argument == "--trace":
			trace = true
		elif argument.begins_with("--difficulty="):
			var value := argument.trim_prefix("--difficulty=")
			if not value.is_valid_int() or int(value) < 0 or int(value) > 3:
				push_error("BOSS_AI: difficulty must be 0..3")
				get_tree().quit(1)
				return
			difficulty = int(value)
		elif argument.begins_with("--characters="):
			characters = Array(argument.trim_prefix("--characters=").split(","))
			if characters.size() != 4 or characters.any(func(id): return Registry.character(id) == null):
				push_error("BOSS_AI: four registered characters required")
				get_tree().quit(1)
				return
	if game_id not in ["boss_colossus", "boss_forge", "boss_dreadnought", "boss_sovereign"]:
		push_error("BOSS_AI: unsupported game")
		get_tree().quit(1)
		return
	var label := "COLOSSUS_AI" if game_id == "boss_colossus" else "BOSS_AI"
	var cfg := MatchConfig.build(game_id, characters, 0, difficulty, seed_value)
	cfg.rounds = 1
	var scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var results := []
	scene.setup({"config": cfg, "on_finished": func(result): results.append(result)})
	var previous_exposure := 0.0
	var window_samples: Array = []
	for tick in 60 * 220:
		if not results.is_empty(): break
		await get_tree().physics_frame
		if trace and game_id == "boss_colossus" and scene.phase == MatchPhase.P.PLAYING:
			var exposure: float = scene.controller._exposed
			if exposure > previous_exposure + 0.01:
				if not window_samples.is_empty():
					print("COLOSSUS_WINDOW ", JSON.stringify(window_samples))
				window_samples.clear()
				for slot in 4:
					window_samples.append({"slot": slot, "active_ticks": 0, "reach_ticks": 0,
						"safe_reach_ticks": 0, "ready_reach_ticks": 0, "swing_ticks": 0,
						"visible_ready_ticks": 0, "delayed_ready_ticks": 0, "danger_ready_ticks": 0,
						"plan_ready_ticks": 0, "lapse_ready_ticks": 0,
						"attack_input_ticks": 0, "cooldown_ticks": 0, "hit": false})
				print("COLOSSUS_TRACE time=", tick / 60.0, " health=", scene.controller.boss_health, " fist=", scene.controller._fist.global_position)
				for fighter in scene.ctx.fighters:
					var plan: Dictionary = scene.controller.attack_plan(fighter.global_position)
					var clear: bool = not plan.is_empty() and scene.arena._crater_floor.path_clear(fighter.global_position - scene.arena.global_position, plan.target - scene.arena.global_position)
					print("COLOSSUS_TRACE slot=", fighter.slot, " position=", fighter.global_position, " velocity=", fighter.velocity, " path_clear=", clear, " plan=", plan)
			if exposure > 0.0 and not window_samples.is_empty():
				for fighter in scene.ctx.fighters:
					var sample: Dictionary = window_samples[fighter.slot]
					if not fighter.alive or not fighter.visible or fighter.global_position.y < -0.5:
						continue
					sample.active_ticks += 1
					if scene.controller.in_reach(fighter, scene.controller._fist.global_position, 1.6):
						sample.reach_ticks += 1
						if scene.arena.is_inside(fighter.global_position, 0.5):
							sample.safe_reach_ticks += 1
							if fighter.control_enabled and fighter._stun <= 0.0 and fighter._hitstop <= 0.0 and fighter.mods["frozen"] <= 0.0:
								sample.ready_reach_ticks += 1
								var brain = scene._brains[fighter.slot]
								if brain.can_observe(scene.controller._fist): sample.visible_ready_ticks += 1
								var samples: Array = brain._weak_history.get(scene.controller._fist.get_instance_id(), [])
								if samples.any(func(entry): return float(entry.time) <= brain._time - brain.reaction_time):
									sample.delayed_ready_ticks += 1
									for index in range(samples.size() - 1, -1, -1):
										if float(samples[index].time) <= brain._time - brain.reaction_time:
											var plan: Dictionary = scene.controller.attack_plan(fighter.global_position, [samples[index].pos])
											if not plan.is_empty() and plan.attack: sample.plan_ready_ticks += 1
											break
								if brain._mistake_timer > 0.0: sample.lapse_ready_ticks += 1
								for zone in scene.controller.danger_zones():
									var offset: Vector3 = fighter.global_position - zone.pos
									offset.y = 0.0
									if offset.length() < float(zone.radius) + float(zone.get("margin", 0.8)) and float(zone.left) > brain.reaction_time * 0.8:
										sample.danger_ready_ticks += 1
										break
						if fighter.is_attacking(): sample.swing_ticks += 1
						if fighter._attack_cd > 0.0: sample.cooldown_ticks += 1
						if (scene._brains[fighter.slot].bits & InputFrame.Btn.ATTACK) != 0:
							sample.attack_input_ticks += 1
					if scene.controller._hit_this_window.has(fighter.slot): sample.hit = true
			if exposure <= 0.0 and previous_exposure > 0.0 and not window_samples.is_empty():
				print("COLOSSUS_WINDOW ", JSON.stringify(window_samples))
				window_samples.clear()
			previous_exposure = exposure
		if tick > 0 and tick % 1800 == 0:
			print(label, " game=", game_id, " time=", tick / 60, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores)
	var passed: bool = not results.is_empty() and scene.controller.boss_defeated
	if not window_samples.is_empty():
		for sample in window_samples:
			if scene.controller._hit_this_window.has(sample.slot): sample.hit = true
		print("COLOSSUS_WINDOW ", JSON.stringify(window_samples))
	print(label, " game=", game_id, " seed=", cfg.seed, " difficulty=", cfg.players[0].ai_difficulty, " defeated=", scene.controller.boss_defeated, " health=", scene.controller.boss_health, " scores=", scene.ctx.scores)
	print(label, ": ", "PASS" if passed else "FAIL")
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if passed else 1)
