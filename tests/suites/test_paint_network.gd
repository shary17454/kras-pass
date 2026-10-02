extends RefCounted

const Paint = preload("res://src/net/paint_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("paint network")
	for id in ["paint_grid", "mnatiq"]:
		var cfg := MatchConfig.build(id, ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		t.equal(game._tiles.size(), Paint.TILE_COUNT, "authored grid size matches protocol")
		var indices := {}
		for tile: ArenaTile in game._tiles:
			var index := Paint._index(tile)
			t.ok(absi(tile.grid_x) <= Paint.EXTENT and absi(tile.grid_z) <= Paint.EXTENT, "authored coordinates fit protocol")
			t.ok(index >= 0 and index < Paint.TILE_COUNT and not indices.has(index), "each authored tile has a unique wire index")
			indices[index] = true
		var replica = load("res://src/net/match_replica.gd").new()
		var corner: ArenaTile = game._tiles[-1]
		corner.claim(1, UIKit.adapt(cfg.players[1].color()))
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.equal(packet.world.owners[Paint._index(corner)], 1.0, "host captures ownership at its authored coordinate")
		t.ok(replica.accept(packet, 4, id), "ownership survives JSON round trip")
		for owner in [-2, 4, 0.5, "1", true, INF]:
			var bad := packet.duplicate(true)
			bad.world.owners[0] = owner
			t.ok(not replica.accept(bad, 4, id), "reject invalid owner")
		for size in [0, 168, 170]:
			var bad := packet.duplicate(true)
			bad.world.owners.resize(size)
			bad.world.owners.fill(-1)
			t.ok(not replica.accept(bad, 4, id), "reject incomplete or oversized grid")
		t.equal(replica.target, packet, "invalid world preserves valid state")
		packet.world.owners[0] = 2
		packet.scores[2] = 12
		t.ok(replica.accept(packet, 4, id), "accept claimed tile")
		var tile: ArenaTile = game._tiles[0]
		var neutral := tile.base_color
		replica.render(scene, 0.1)
		t.equal(tile.owner_slot, 2, "guest receives tile owner")
		t.equal(tile._mesh.material_override.albedo_color, UIKit.adapt(cfg.players[2].color()), "guest paints owner color")
		t.equal(tile.base_color, neutral, "ownership does not overwrite neutral color")
		var material = tile._mesh.material_override
		for i in 10:
			replica.render(scene, 0.1)
		t.equal(tile._mesh.material_override, material, "unchanged owners reuse material")
		t.equal(scene.ctx.scores[2], 12, "guest never recounts scores from local tiles")
		if id == "mnatiq":
			t.equal(int(scene.ctx.details[2].get("regions", 0)), 0, "guest never triggers enclosed-region rewards")
		packet.world.owners[0] = -1
		t.ok(replica.accept(packet, 4, id), "accept neutral reset")
		replica.render(scene, 0.1)
		t.equal(tile.owner_slot, -1, "reset clears guest ownership")
		t.equal(tile._mesh.material_override.albedo_color, neutral, "reset restores neutral appearance")
		if DisplayServer.get_name() != "headless":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--capture-paint="):
					for index in Paint.TILE_COUNT:
						packet.world.owners[index] = index % 4
					t.ok(replica.accept(packet, 4, id), "accept visual ownership fixture")
					replica.render(scene, 0.1)
					await host.get_tree().process_frame
					await RenderingServer.frame_post_draw
					var path: String = arg.trim_prefix("--capture-paint=") + "-" + id + ".png"
					t.equal(host.get_viewport().get_texture().get_image().save_png(path), OK, "save paint evidence")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
