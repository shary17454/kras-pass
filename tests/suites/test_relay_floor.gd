extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("relay physical floor and cargo recovery")
	var cfg := MatchConfig.build("crate_relay", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 115)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var arena: Arena = scene.arena
	var game = scene.controller
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var r: float = arena.def.radius
	for x in [-1.1, -0.9, -0.5, -0.3, 0.0, 0.3, 0.5, 0.9, 1.1]:
		for z in [-1.1, -0.9, -0.5, -0.3, 0.0, 0.3, 0.5, 0.9, 1.1]:
			var position: Vector3 = arena.global_position + Vector3(x * r, 0, z * r)
			var expected: bool = (absf(x) <= 1 and absf(z) <= 0.25) or (absf(z) <= 1 and absf(x) <= 0.25) or Vector2(x, z).length() <= 0.425
			t.equal(arena.is_inside(position), expected, "cross query matches authored floor")
			t.equal(arena.edge_distance(position) >= 0.0, expected, "signed edge agrees with floor")
			var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 5, position + Vector3.DOWN * 3, 1)
			var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
			t.equal(not hit.is_empty(), expected, "physics ground agrees with floor query")
	t.near(arena.edge_distance(arena.global_position), r * 0.425, 0.001, "center measures exposed circular edge")
	t.near(arena.edge_distance(arena.global_position + Vector3(r * 0.7, 0, 0)), r * 0.25, 0.001, "arm center measures side edge")
	t.ok(not arena.is_inside(arena.global_position + Vector3(r - 0.2, 0, 0), 0.6), "cargo margin excludes arm tip")
	var fighter: Fighter = scene.ctx.fighter(0)
	for position in [Vector3(r * 0.7, -20, r * 0.7), Vector3(r + 5, 1, 0), Vector3(0, -20, 0), Vector3(0, 1, 0)]:
		fighter.carrying = 1
		fighter.global_position = arena.global_position + position
		game._drop(0, -1)
		var item: Collectible = game._items.back()
		t.ok(arena.is_inside(item.global_position, 0.6), "dropped cargo remains on reachable floor")
		t.near(item._base_y, arena.global_position.y + 1.0, 0.001, "dropped cargo is above ground even after falling")
		t.equal(item.owner_slot, 0, "recovery preserves pickup grace owner")
		t.ok(item._grace > 0, "recovery preserves pickup grace time")
	var stranded: Collectible = game._items[0]
	stranded.place(arena.global_position + Vector3(r * 0.6, -5, r * 0.6))
	var scores := Array(scene.ctx.scores)
	game.tick(0.01)
	t.ok(arena.is_inside(stranded.global_position, 0.6), "existing stranded cargo recovers during tick")
	t.near(stranded._base_y, arena.global_position.y + 1.0, 0.001, "recovery restores ground height")
	t.equal(Array(scene.ctx.scores), scores, "recovery cannot award a delivery")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
