extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("shared contact equation across duel and ring")
	var rows: Array[Dictionary] = []
	for game_id in ["duel_pit", "ring_rumble"]:
		var cfg := MatchConfig.build(game_id, ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 117)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var attacker: Fighter = scene.ctx.fighter(0)
		var victim: Fighter = scene.ctx.fighter(1)
		for character in Registry.characters():
			attacker.data = character
			attacker._apply_character()
			for target in Registry.characters():
				victim.data = target
				victim._apply_character()
				for damage in [0.0, 40.0, 100.0]:
					for closing in [4.5, 8.0, 12.0]:
						for dash in [false, true]:
							for modified in [false, true]:
								attacker._dash_time = 0.1 if dash else 0.0
								attacker.mods["weight"] = 1.2 if modified else 1.0
								attacker.mods["push"] = 1.15 if modified else 1.0
								victim.mods["weight"] = 0.8 if modified else 1.0
								victim.mods["resist_taken"] = 0.85 if modified else 1.0
								victim.mutator["knockback_taken"] = 0.9 if modified else 1.0
								victim._impulse = Vector3.ZERO
								victim._invuln = 0.0
								victim.damage_percent = damage
								victim.health = victim.max_health
								var tuning: Dictionary = attacker._tuning
								var mass := attacker.knock_resist * float(attacker.mods["weight"])
								var their_mass := victim.knock_resist * float(victim.mods["weight"])
								var ratio := clampf(mass / maxf(0.3, their_mass), 0.78, 1.35)
								var strength: float = closing * float(tuning.get("ram_scale", 1.3)) \
									* ratio * attacker.knock_power * float(attacker.mods["push"])
								if dash:
									strength *= float(tuning.get("ram_dash_bonus", 1.7))
								var expected: float = strength * (1.0 + damage * float(tuning.get("damage_knock_scale", 0.011))) \
									* float(victim.mutator["knockback_taken"]) * float(victim.mods["resist_taken"]) \
									/ maxf(0.3, victim.knock_resist * float(victim.mods["weight"]))
								attacker._deal_ram(victim, Vector3.RIGHT, closing, Vector3.ZERO, tuning)
								var label := "%s %s->%s damage=%.0f speed=%.1f dash=%s modified=%s" % [
									game_id, character.id, target.id, damage, closing, dash, modified]
								t.near(victim._impulse.x, expected, 0.0001, label)
								t.near(victim.damage_percent, damage + float(tuning.get("ram_damage", 4.0)),
									0.0001, "contact preserves damage accumulation")
								rows.append({"game": game_id, "attacker": character.id, "victim": target.id,
									"damage": damage, "closing": closing, "dash": dash, "modified": modified,
									"push": victim._impulse.x, "contract_push": expected})
			await host.get_tree().process_frame
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	var file := FileAccess.open(SaveSystem.storage_root.path_join("duel-contact-matrix.json"), FileAccess.WRITE)
	t.ok(file != null, "controlled measurements are saved in isolated test storage")
	if file != null:
		file.store_string(JSON.stringify({"cases": rows.size(), "rows": rows}))
		file.close()
