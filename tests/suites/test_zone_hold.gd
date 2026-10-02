extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("zone hold")
	var cfg := MatchConfig.build("zone_hold", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	for i in 4:
		scene.ctx.fighters[i].global_position = Vector3(100 + i * 10, 0, 100)
	game.zone_position = Vector3.ZERO
	game._target = Vector3.ZERO
	game._move_timer = 100.0
	scene.ctx.fighters[0].global_position = Vector3.ZERO
	game.tick(0.75)
	t.equal(scene.ctx.scores[0], 0, "partial capture does not award a point")
	var owned_material = game._ring.material_override
	game.tick(0.1)
	t.equal(game._ring.material_override, owned_material, "unchanged ownership reuses material")
	t.equal(game._ring_color, UIKit.adapt(cfg.players[0].color()), "owner color is visible")
	scene.ctx.fighters[1].global_position = Vector3.ZERO
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
	game.zone_position = Vector3.ZERO
	game._target = Vector3.ZERO
	game.tick(0.2)
	t.equal(scene.ctx.scores[0], 0, "fractional points cannot carry across rounds")
	game.tick(0.8)
	t.equal(scene.ctx.scores[0], 1, "a full uncontested second awards one point")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
