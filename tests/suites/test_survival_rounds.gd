extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("survival hazard round reset")
	for id in ["rising_tide", "sweeper_storm"]:
		var cfg := MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var arena: Arena = scene.arena
		arena.set_hazard_speed(2.0)
		for cycle in 3:
			scene.controller.on_round_start()
			for hazard in arena._hazards:
				if hazard is ArenaHazards.RisingWater or hazard is ArenaHazards.Sweeper:
					var expected: float = arena._base_hazard_speed[hazard.get_instance_id()] * 2.0
					t.equal(hazard.speed, expected, "round restores configured hazard speed")
					t.equal(hazard._age, 0.0, "round clears acceleration age")
					if hazard is ArenaHazards.RisingWater:
						t.equal(hazard._mesh.position.y, 0.0, "round clears visual wave offset")
						t.ok(hazard._hit.is_empty(), "round clears submerged players")
					hazard.tick(3.0)
					if hazard is ArenaHazards.RisingWater:
						hazard._hit[0] = true
			scene.controller.on_sudden_death()
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
