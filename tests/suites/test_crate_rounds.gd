extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("crate round lifecycle")
	for id in ["crate_smash", "lab_crates"]:
		var cfg := MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 110)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		game._crates[0].bomb = false
		game._crates[0].erase("weapon")
		game._break_crate(0, 0)
		game._spawn_timer = -9.0
		var old: Array = []
		for entry in game._crates:
			old.append(entry.node)
		var shots: Array = []
		if id == "lab_crates":
			game._volley(0, Vector3(0, 1, 0))
			shots = game._shots.duplicate()
		var scores := Array(scene.ctx.scores)
		game.on_round_start()
		t.equal(game._crates.size(), game.FIELD_TARGET, id + " restores full field")
		t.near(game._spawn_timer, 1.1, 0.00001, id + " resets spawn clock")
		t.equal(Array(scene.ctx.scores), scores, id + " reset cannot award points")
		for body in old:
			t.ok(body.is_queued_for_deletion(), id + " retires prior crate")
			t.equal(body.collision_layer, 0, id + " removes old collision immediately")
		if id == "lab_crates":
			t.ok(game._shots.is_empty(), "lab clears previous volley")
			for shot in shots:
				t.ok(not shot.active and not shot.visible, "old shot cannot cause damage after reset")
				t.ok(shot.is_queued_for_deletion(), "old shot is reclaimed")
		game._crates[0].bomb = true
		game._crates[0].erase("weapon")
		var position := Vector3(4, 0.75, -3)
		game._crates[0].node.global_position = position
		game._break_crate(0, 0)
		var burst: Node3D = scene.ctx.world_root.get_child(scene.ctx.world_root.get_child_count() - 1)
		t.ok(burst.global_position.is_equal_approx(position), id + " explosion appears at broken crate")
		game.cleanup()
		game.cleanup()
		t.ok(game._crates.is_empty(), id + " repeated cleanup is safe")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
