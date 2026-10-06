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
		if id == "paint_grid":
			await _simultaneous_dash_claims(t, scene, host)
			game.on_round_start()
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


func _simultaneous_dash_claims(t: TestHarness, scene: Node, host: Node) -> void:
	var game = scene.controller
	var arena: Arena = scene.arena
	var centre: ArenaTile
	var adjacent: Array[ArenaTile] = []
	for tile: ArenaTile in game._tiles:
		if tile.grid_x == 0 and tile.grid_z == 0:
			centre = tile
		if absi(tile.grid_x) + absi(tile.grid_z) == 1:
			adjacent.append(tile)
	t.ok(centre != null and adjacent.size() == 4, "paint contention fixture has four symmetric neighbouring tiles")
	if centre == null or adjacent.size() != 4:
		return
	var masks: Array[int] = []
	for slot in 4:
		var body: Fighter = scene.ctx.fighter(slot)
		masks.append(body.collision_mask)
		body.collision_mask = 1
		body.global_position = adjacent[slot].global_position + Vector3.UP * 0.01
	for frame in 12:
		await host.get_tree().physics_frame
		for body: Fighter in scene.ctx.fighters:
			body.velocity = Vector3.DOWN * 3.0
			body.move_and_slide()
	for body: Fighter in scene.ctx.fighters:
		t.ok(body.is_on_floor(), "simultaneous paint claimant stands on native tile collider")
		body._dash_time = 0.2
	var claims := [0, 0, 0, 0]
	for frame in 16:
		game.tick(1.0 / 60.0)
		t.ok(centre.owner_slot >= 0 and centre.owner_slot < 4, "contested dash tile has one valid owner")
		if centre.owner_slot >= 0 and centre.owner_slot < 4:
			claims[centre.owner_slot] += 1
	for count in claims:
		t.equal(count, 4, "identical simultaneous claims do not grant a permanent higher-slot advantage")
	var nearest: Fighter = scene.ctx.fighter(0)
	nearest.global_position = centre.global_position + Vector3.UP * 0.01
	nearest._dash_time = 0.0
	for frame in 4:
		await host.get_tree().physics_frame
		nearest.velocity = Vector3.DOWN
		nearest.move_and_slide()
		game.tick(1.0 / 60.0)
		t.ok(nearest.is_on_floor(), "nearest paint claimant is grounded on the actual contested tile")
		t.equal(centre.owner_slot, 0, "closer walking contact outranks distant dash claims regardless of tie priority")
	game.on_round_start()
	t.equal(game._claim_priority, posmod(scene.ctx.config.seed + scene.ctx.round_index, 4), "new round restores deterministic claim priority")
	t.ok(game._claims.is_empty(), "new round retains no preceding claim requests")
	for slot in 4:
		var body: Fighter = scene.ctx.fighter(slot)
		body._dash_time = 0.0
		body.collision_mask = masks[slot]
