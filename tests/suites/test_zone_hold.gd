extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("zone hold")
	var cfg := MatchConfig.build("zone_hold", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var arena: Arena = scene.arena
	var band := arena.def.radius * 0.72
	for step in 56:
		var angle := TAU * step / 56.0
		for radius in [arena.def.radius * 0.45 + 0.5, band, arena.def.radius - 0.5]:
			var position: Vector3 = arena.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 5, position + Vector3.DOWN * 3, 1)
			t.ok(not arena.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "ring ground step=%d radius=%.3f" % [step, radius])
		var hole_position := arena.global_position + Vector3(cos(angle), 0, sin(angle)) * (arena.def.radius * 0.45 - 0.5)
		t.ok(not arena.is_inside(hole_position), "ring central hole is not walkable")
		t.ok(arena.edge_distance(hole_position) < 0.0, "ring central hole has negative edge distance")
	game.zone_position = arena.global_position + Vector3(band, 0, 0)
	game._target = arena.global_position + Vector3(-band, 0, 0)
	game._move_timer = 100.0
	for i in 4:
		scene.ctx.fighters[i].global_position = Vector3(100 + i * 10, 0, 100)
	for step in 120:
		var previous: Vector3 = game.zone_position
		game.tick(0.1)
		t.near((game.zone_position - arena.global_position).length(), band, 0.001, "moving zone follows annulus instead of crossing central hole")
		t.ok(game.zone_position.distance_to(previous) <= 0.3201, "arc movement preserves speed budget")
	t.ok(game.zone_position.distance_to(game._target) < 0.001, "arc movement reaches opposite target")
	game.on_round_start()
	for i in 4:
		scene.ctx.fighters[i].global_position = Vector3(100 + i * 10, 0, 100)
	var capture_position := arena.global_position + Vector3(band, 0, 0)
	game.zone_position = capture_position
	game._target = capture_position
	game._move_timer = 100.0
	scene.ctx.fighters[0].global_position = capture_position
	game.tick(0.75)
	t.equal(scene.ctx.scores[0], 0, "partial capture does not award a point")
	var owned_material = game._ring.material_override
	game.tick(0.1)
	t.equal(game._ring.material_override, owned_material, "unchanged ownership reuses material")
	t.equal(game._ring_color, UIKit.adapt(cfg.players[0].color()), "owner color is visible")
	scene.ctx.fighters[1].global_position = capture_position
	game.tick(0.5)
	t.equal(scene.ctx.scores[0], 0, "contested capture pauses scoring")
	t.equal(game._ring_color, game.CONTESTED_COLOR, "contested state is visible")
	game.on_sudden_death()
	t.near(game.zone_radius, 2.04, 0.001, "sudden death shrinks capture boundary")
	t.near(game._marker.scale.x, 0.6, 0.001, "visible width matches smaller capture zone")
	t.near(game._marker.scale.z, 0.6, 0.001, "visible depth matches smaller capture zone")
	t.near(game._marker.scale.y, 1.0, 0.001, "height does not sink into arena")
	game.on_round_start()
	game.on_round_start()
	t.near(game.zone_radius, 3.4, 0.001, "next round restores default capture boundary")
	t.equal(game._marker.scale, Vector3.ONE, "next round restores visible boundary")
	t.equal(game._ring_color, UIKit.ACCENT_2, "next round clears previous owner color")
	scene.ctx.fighters[1].global_position = Vector3(100, 0, 100)
	game.zone_position = capture_position
	game._target = capture_position
	game.tick(0.2)
	t.equal(scene.ctx.scores[0], 0, "fractional points cannot carry across rounds")
	game.tick(0.8)
	t.equal(scene.ctx.scores[0], 1, "a full uncontested second awards one point")
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "zone_hold"), "zone world survives JSON round trip")
	for field in ["position", "radius", "color"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "zone_hold"), "reject missing zone " + field)
	for radius in [0, 11, INF, "3", true]:
		var bad := packet.duplicate(true)
		bad.world.radius = radius
		t.ok(not replica.accept(bad, 4, "zone_hold"), "reject invalid radius")
	for color in ["red", "0xffffff", "zzzzzzzz"]:
		var bad := packet.duplicate(true)
		bad.world.color = color
		t.ok(not replica.accept(bad, 4, "zone_hold"), "reject invalid color")
	var bad := packet.duplicate(true)
	bad.world.position[0] = INF
	t.ok(not replica.accept(bad, 4, "zone_hold"), "reject invalid position")
	t.equal(replica.target, packet, "invalid state preserves last valid snapshot")
	packet.world.position = [5, 0, 6]
	packet.world.radius = 2.04
	packet.world.color = game.CONTESTED_COLOR.to_html()
	t.ok(replica.accept(packet, 4, "zone_hold"), "accept changed capture state")
	var accum: Array = game._accum.duplicate()
	for i in 10:
		replica.render(scene, 0.1)
	t.equal(game._marker.global_position, Vector3(5, 0, 6), "guest marker follows authority")
	t.near(game._marker.scale.x, 0.6, 0.001, "guest renders reduced capture radius")
	t.equal(game._ring_color, game.CONTESTED_COLOR, "guest renders contested ownership")
	t.equal(game._accum, accum, "guest rendering never advances capture progress")
	t.equal(scene.ctx.scores[0], 1, "guest rendering never awards score")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	var oval := Arena.new()
	host.add_child(oval)
	oval.position = Vector3(60, 0, -40)
	oval.build(Registry.arena("circuit_loop"))
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	for step in 80:
		var angle := TAU * step / 80.0
		for radius in [oval.def.radius * 0.55 + 0.5, oval.def.radius * 0.775, oval.def.radius - 0.5, oval.def.radius * 0.55 - 0.5]:
			var position: Vector3 = oval.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
			var expected: bool = radius > oval.def.radius * 0.55
			var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 5, position + Vector3.DOWN * 3, 1)
			var hit := oval.get_world_3d().direct_space_state.intersect_ray(ray)
			# Inner boundary walls are not playable floor, even when a ray hits them.
			var has_floor: bool = not hit.is_empty() and absf(hit.position.y - oval.global_position.y) < 0.01
			t.equal(has_floor, expected, "oval physical band step=%d radius=%.3f" % [step, radius])
			t.equal(oval.is_inside(position), expected, "oval query matches band")
			t.equal(oval.edge_distance(position) >= 0.0, expected, "oval signed edge matches band")
	for body in oval._static_root.get_children():
		if not body is StaticBody3D:
			continue
		var collision: CollisionShape3D = body.get_child(1)
		if not collision.shape is BoxShape3D or collision.shape.size.y != oval.def.wall_height:
			continue
		var radial: Vector3 = Vector3(body.position.x, 0, body.position.z).normalized()
		t.near(absf(body.basis.x.dot(radial)), 0.0, 0.001, "ring walls run tangent rather than pointing into track")
	oval.queue_free()
	await host.get_tree().process_frame
