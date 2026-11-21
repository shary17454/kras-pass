extends RefCounted

const CASES := [
	["tank_arena", "tank_foundry"],
	["tank_arena", "tank_oasis"],
	["tank_arena", "tank_frost"],
	["duel_pit", "duel_pit"],
	["duel_pit", "iron_flats"],
	["turret_duel", "iron_flats"],
	["boss_dreadnought", "iron_flats"],
	["base_siege", "iron_flats"],
]


func run(t: TestHarness, host: Node) -> void:
	t.suite("authored arena spawn clearance")
	var rosters: Array[Array] = [
		["nabta", "sakhra", "fanoos", "ramla"],
		["barq", "mowja", "ghaim", "turs"],
	]
	for pair in CASES:
		var variants: Array[Array] = rosters.duplicate()
		if pair[0] == "tank_arena":
			variants.clear()
			for roster in rosters:
				for rotation in 4:
					var rotated: Array = []
					for seat in 4:
						rotated.append(roster[(seat + rotation) % 4])
					variants.append(rotated)
		for roster in variants:
			var characters: Array[String] = []
			characters.assign(roster)
			var config := MatchConfig.build(String(pair[0]), characters, 0, 3, 80009001)
			config.arena_id = String(pair[1])
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": config})
			scene.set_physics_process(false)
			var context: MatchContext = scene.ctx
			for fighter: Fighter in context.fighters:
				fighter.set_physics_process(false)
			await host.get_tree().physics_frame
			await host.get_tree().physics_frame
			for fighter: Fighter in context.fighters:
				var body := fighter.get_node("Body") as CollisionShape3D
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = body.shape
				query.transform = body.global_transform
				query.exclude = [fighter.get_rid()]
				var hits: Array[Dictionary] = fighter.get_world_3d().direct_space_state.intersect_shape(query, 64)
				var obstacles: Array[String] = []
				for hit in hits:
					if hit.collider is StaticBody3D:
						obstacles.append(String(hit.collider.get_path()))
				t.ok(obstacles.is_empty(), "%s/%s %s slot %d starts clear of solid geometry: %s" %
					[pair[0], pair[1], fighter.data.id, fighter.slot, obstacles])
				t.ok(context.arena.is_inside(fighter.global_position, 0.5),
					"authored spawn remains inside the playable arena")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
