extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("sovereign final phase remains winnable")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_sovereign", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 345), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	var game: Node = scene.controller
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.global_position = game.boss_node.global_position + Vector3(1, 0, 0)
	fighter._attack_time = 0.2
	game.boss_think(0.01)
	t.near(game.boss_health, 1500.0, 0.001, "pursuit remains armored outside recovery")
	game.damage_boss(900.0, 1)
	game._raise_shield()
	game.boss_think(0.01)
	t.near(game.boss_health, 600.0, 0.001, "siege shield still rejects core strikes")
	game.damage_boss(200.0, 1)
	t.equal(game.phase, 2, "damage transition enters collapse")
	t.ok(not game._shielded, "collapse removes shield")
	fighter._attack_time = 0.0
	game.boss_think(game.RECOVER_TIME + 0.1)
	t.ok(game._recover <= 0.0, "initial collapse recovery is over")
	var health: float = game.boss_health
	fighter._attack_time = 0.2
	game.boss_think(0.01)
	t.near(game.boss_health, health - game.CORE_DAMAGE, 0.001, "collapse accepts core strike after recovery")
	health = game.boss_health
	game.boss_think(0.01)
	t.near(game.boss_health, health, 0.001, "same swing is never scored twice")
	for swing in 6:
		fighter._attack_time = 0.0
		game.boss_think(0.01)
		fighter._attack_time = 0.2
		if swing == 5: game._collapse_timer = 0.0
		game.boss_think(0.01)
	t.ok(game.boss_defeated, "separate real core strikes finish collapse")
	t.ok(scene.ctx.early_finish and not game.boss_node.visible, "defeat signals finish and hides boss")
	t.ok(scene.ctx.scores[0] > 0, "core damage credited to attacking player")
	t.empty(game._telegraphs, "lethal strike cannot start a new collapse attack")
	scene._start_next_round()
	t.near(game.boss_health, 1500.0, 0.001, "next round resets final phase health")
	t.equal(game.phase, 0, "next round resets pursuit")
	t.empty(game._hit_window, "next round releases old attack windows")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
