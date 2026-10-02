extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("paint reset")
	for id in ["paint_grid", "mnatiq", "mukharrib"]:
		var cfg := MatchConfig.build(id, ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		var tile: ArenaTile = game._tiles[0]
		var neutral := tile.base_color
		var paint := UIKit.adapt(cfg.players[0].color())
		t.ok(tile.claim(0, paint), id + " changes ownership")
		t.equal(tile.base_color, neutral, id + " preserves neutral color")
		t.equal(tile._mesh.material_override.albedo_color, paint, id + " displays owner color")
		t.ok(not tile.claim(0, paint), id + " repeated claim does not change ownership")
		game._recount_scores()
		t.equal(scene.ctx.scores[0], 1, id + " counts claimed tile")
		if id == "mukharrib":
			game._target = tile
			game._scrub()
			t.equal(tile.owner_slot, -1, "scrub clears owner")
			t.equal(tile._mesh.material_override.albedo_color, neutral, "scrub restores neutral visual")
			t.equal(scene.ctx.scores[0], 0, "scrub recounts score")
			tile.claim(0, paint)
		scene.arena.reset_hazards()
		game.on_round_start()
		t.equal(tile.owner_slot, -1, id + " next round clears owner")
		t.equal(tile.base_color, neutral, id + " next round retains neutral color")
		t.equal(tile._mesh.material_override.albedo_color, neutral, id + " next round resets visual")
		t.equal(scene.ctx.scores[0], 0, id + " next round resets score")
		tile.claim(1, UIKit.adapt(cfg.players[1].color()))
		game.on_round_start()
		t.equal(tile._mesh.material_override.albedo_color, neutral, id + " repeated rounds restore neutral")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
