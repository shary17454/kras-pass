extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Items = preload("res://src/net/collectible_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("collection network")
	await _gem_surface_placement(t, host)
	await _island_bridge_walking(t, host)
	for game_id in ["gem_grab", "star_rush", "crate_relay"]:
		t.test("%s host-owned pickups and carrying" % game_id)
		var cfg := MatchConfig.build(game_id, ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		var replica = Replica.new()
		var carried := 1 if game_id == "crate_relay" else 3
		scene.ctx.fighters[0].carrying = carried
		scene.ctx.set_score(0, 5)
		var expected_scores: Array = Array(scene.ctx.scores)
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(packet.world.items.size() >= (4 if game_id == "crate_relay" else 6), "capture live authored pickups")
		t.ok(replica.accept(packet, 4, game_id), "accept serialized world")
		for field in ["items", "carrying"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, 4, game_id), "reject missing " + field)
		var invalid := packet.duplicate(true)
		invalid.world.carrying[0] = 2 if game_id == "crate_relay" else 9
		t.ok(not replica.accept(invalid, 4, game_id), "carrying obeys game cap")
		for id in ["", "-1", "01", "+1", " 1", "9223372036854775808"]:
			invalid = packet.duplicate(true)
			invalid.world.items[0].id = id
			t.ok(not replica.accept(invalid, 4, game_id), "reject noncanonical item identity")
		for color in ["red", "fffffffff", "zzzzzzzz", "0xffffff", "-fffffff"]:
			invalid = packet.duplicate(true)
			invalid.world.items[0].color = color
			t.ok(not replica.accept(invalid, 4, game_id), "reject malformed visual color")
		invalid = packet.duplicate(true)
		invalid.world.items[1].id = invalid.world.items[0].id
		t.ok(not replica.accept(invalid, 4, game_id), "reject duplicate identity")
		invalid = packet.duplicate(true)
		invalid.world.items[0].position[0] = INF
		t.ok(not replica.accept(invalid, 4, game_id), "reject non-finite item position")
		invalid = packet.duplicate(true)
		invalid.world.items[0].kind = "gem" if game_id == "crate_relay" else "crate"
		t.ok(not replica.accept(invalid, 4, game_id), "game controls permitted item kinds")
		replica.render(scene, 0.016)
		t.equal(game._items.size(), 0, "guest releases locally generated pickups")
		var view: Node3D = replica._collectibles
		t.equal(view.views.size(), packet.world.items.size(), "all host pickups appear")
		t.equal(view.find_children("*", "CollisionObject3D", true, false).size(), 0, "replica contains no colliders")
		t.equal(scene.ctx.fighters[0].carrying, carried, "HUD receives host carried count")
		if game_id == "crate_relay":
			t.equal(game._carry_marks.size(), 1, "host cargo appears above guest player")
			t.ok(not EventBus.player_hit.is_connected(game._on_player_hit), "guest removes authoritative hit observer")
			var rejected := packet.duplicate(true)
			rejected.world.extra = true
			t.ok(not replica.accept(rejected, 4, game_id), "reject undeclared relay fields")
			rejected = packet.duplicate(true)
			for i in 9:
				var row: Dictionary = packet.world.items[0].duplicate(true)
				row.id = str(1000 + i)
				rejected.world.items.append(row)
			t.ok(not replica.accept(rejected, 4, game_id), "reject unbounded relay cargo")
		var id: String = packet.world.items[0].id
		var existing: Node3D = view.views[id]
		replica.render(scene, 0.016)
		t.equal(view.views[id], existing, "unchanged snapshots reuse visuals")
		packet.world.items[0].color = "ff0000ff"
		t.ok(replica.accept(packet, 4, game_id), "accept reused pool identity with new appearance")
		replica.render(scene, 0.016)
		t.ok(view.views[id] != existing, "refresh style when pooled item changes")
		packet.world.items.clear()
		packet.world.carrying[0] = 0
		t.ok(replica.accept(packet, 4, game_id), "empty field is valid")
		replica.render(scene, 0.016)
		t.equal(view.views.size(), 0, "collection removes presentation node")
		t.equal(scene.ctx.fighters[0].carrying, 0, "deposit clears carried HUD count")
		if game_id == "crate_relay":
			t.equal(game._carry_marks.size(), 0, "deposit removes guest cargo visual")
		t.equal(Array(scene.ctx.scores), expected_scores, "render never awards pickup or deposit points")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	t.test("bounded collection payload")
	var rows: Array = []
	for i in Items.MAX_ITEMS:
		rows.append({"id": str(9223372036854775807 - i), "kind": "gem", "position": [9999.999, -9999.999, 9999.999],
			"rotation": -3.142, "color": "ffffffff", "size": 0.42, "value": 1000000})
	t.ok(Items.valid(rows, "gem"), "maximum field accepted")
	t.ok(JSON.stringify(rows).to_utf8_buffer().size() < 43000, "bounded rows leave space for players inside snapshot limit")
	rows.append(rows[0].duplicate(true))
	t.ok(not Items.valid(rows, "gem"), "oversized field rejected")


func _gem_surface_placement(t: TestHarness, host: Node) -> void:
	for arena_id in ["gem_hollow", "glass_terrace"]:
		t.test("%s gems remain above actual island surfaces" % arena_id)
		var cfg := MatchConfig.build("gem_grab", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 814)
		cfg.arena_id = arena_id
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.arena.position = Vector3(30, 5, -20)
		await host.get_tree().physics_frame
		await host.get_tree().physics_frame
		var raised := 0
		for sample in 120:
			var spot: Vector3 = scene.controller._random_spot(scene.arena)
			var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 5, spot - Vector3.UP * 5, 1)
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
			t.ok(not hit.is_empty(), "random gem destination has a real supporting collider")
			if not hit.is_empty():
				t.near(spot.y, hit.position.y + 1.1, 0.001, "gem clearance follows floor height instead of arena origin")
				if hit.position.y > scene.arena.global_position.y + 1.5:
					raised += 1
			t.ok(scene.controller._has_ground(spot), "raised gem retains its existing ground validity contract")
		t.ok(raised > 0, "fixture actually covers the highest satellite island")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _island_bridge_walking(t: TestHarness, host: Node) -> void:
	for arena_id in ["gem_hollow", "glass_terrace"]:
		for characters in [["fanoos", "nabta", "ramla", "sakhra"], ["barq", "mowja", "ghaim", "turs"]]:
			var cfg := MatchConfig.build("gem_grab", characters, 0, 1, 814)
			cfg.arena_id = arena_id
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": cfg, "on_finished": func(_r): pass})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
				fighter.collision_layer = 0
				fighter.collision_mask = 1
				fighter.control_enabled = true
				fighter.can_jump = false
			await host.get_tree().physics_frame
			await host.get_tree().physics_frame
			for slot in 4:
				t.ok(not scene._torn_down, "bridge fixture remains live for every player")
				var fighter: Fighter = scene.ctx.fighter(slot)
				for island in 5:
					var angle := TAU * island / 5.0
					var direction := Vector3(cos(angle), 0, sin(angle))
					var height := -0.2 + float(island % 3) * 0.9
					for outbound in [true, false]:
						t.test("%s %s island %d walking %s" % [arena_id, characters[slot], island, "out" if outbound else "back"])
						var start: Vector3 = direction * scene.arena.def.radius * (0.38 if outbound else 0.62)
						var target: Vector3 = direction * scene.arena.def.radius * (0.62 if outbound else 0.38)
						fighter.global_position = scene.arena.global_position + start + Vector3.UP * ((0.0 if outbound else height) + 1.3)
						fighter.velocity = Vector3.ZERO
						var frame := InputFrame.new()
						for step in 30:
							await host.get_tree().physics_frame
							fighter.tick(frame, 1.0 / 60.0)
						frame.move = Vector2(direction.x, direction.z) * (1.0 if outbound else -1.0)
						var reached := false
						for step in 180:
							await host.get_tree().physics_frame
							fighter.tick(frame, 1.0 / 60.0)
							var offset: Vector3 = fighter.global_position - scene.arena.global_position
							if Vector2(offset.x - target.x, offset.z - target.z).length() < 0.25:
								reached = true
								break
						t.ok(reached, "actual fighter crosses the bridge using movement only")
						t.ok(fighter.is_on_floor(), "crossing ends on supporting ground")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	await _island_ai_routes(t, host)


func _island_ai_routes(t: TestHarness, host: Node) -> void:
	for arena_id in ["gem_hollow", "glass_terrace"]:
		for characters in [["fanoos", "nabta", "ramla", "sakhra"], ["barq", "mowja", "ghaim", "turs"]]:
			var cfg := MatchConfig.build("gem_grab", characters, 0, 1, 814)
			cfg.arena_id = arena_id
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": cfg, "on_finished": func(_r): pass})
			scene.set_physics_process(false)
			scene.arena.position = Vector3(30, 5, -20)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
				fighter.collision_layer = 0
				fighter.collision_mask = 1
				fighter.control_enabled = true
				fighter.can_jump = false
			await host.get_tree().physics_frame
			await host.get_tree().physics_frame
			for slot in 4:
				var fighter: Fighter = scene.ctx.fighter(slot)
				var brain := AIBrain.new()
				brain.configure(slot, scene.ctx, 3, 814)
				brain.accuracy = 1.0
				for island in 5:
					t.test("%s %s routing island %d" % [arena_id, characters[slot], island])
					var angle := TAU * island / 5.0
					var destination := (island + 2) % 5
					var target_angle := TAU * destination / 5.0
					var target: Vector3 = scene.arena.global_position + Vector3(cos(target_angle), 0, sin(target_angle)) * scene.arena.def.radius * 0.78
					fighter.global_position = scene.arena.global_position + Vector3(cos(angle), 0, sin(angle)) * scene.arena.def.radius * 0.78
					fighter.global_position.y += -0.2 + float(island % 3) * 0.9 + 1.3
					fighter.velocity = Vector3.ZERO
					var frame := InputFrame.new()
					for step in 30:
						await host.get_tree().physics_frame
						fighter.tick(frame, 1.0 / 60.0)
					var reached := false
					for step in 600:
						await host.get_tree().physics_frame
						brain.steer_to(target)
						frame.move = brain.move
						fighter.tick(frame, 1.0 / 60.0)
						var offset: Vector3 = fighter.global_position - target
						if Vector2(offset.x, offset.z).length() < 0.4 and fighter.is_on_floor():
							reached = true
							break
						if fighter.global_position.y < scene.arena.fall_y:
							break
					t.ok(reached, "shared AI steering reaches another island without falling or jumping")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
