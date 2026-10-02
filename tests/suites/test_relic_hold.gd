extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("relic hold")
	var cfg := MatchConfig.build("relic_hold", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var fighter: Fighter = scene.ctx.fighters[0]
	game.on_round_start()
	t.ok(fighter.can_attack, "initial player can attack")
	game._on_taken(game._relic, 0)
	t.equal(game.holder(), 0, "pickup sets holder")
	t.equal(fighter.carrying, 1, "holder carries relic")
	t.ok(not fighter.can_attack, "holder cannot attack")
	game._accum = 0.7
	game.on_round_start()
	t.equal(game.holder(), -1, "round reset releases holder")
	t.equal(fighter.carrying, 0, "round reset clears carrying")
	t.ok(fighter.can_attack, "round reset restores attack permission")
	t.near(game._accum, 0.0, 0.001, "fractional score does not leak between rounds")
	t.ok(is_instance_valid(game._relic) and game._relic.available, "new round offers a collectible")
	var item: Collectible = game._relic
	game.on_round_start()
	t.equal(game._relic, item, "repeated round callback does not duplicate relic")
	game._on_taken(game._relic, 0)
	game.cleanup()
	game.cleanup()
	t.equal(game.holder(), -1, "cleanup releases ownership")
	t.equal(fighter.carrying, 0, "cleanup clears carrying")
	t.ok(fighter.can_attack, "cleanup restores attack permission")
	t.ok(game._relic == null and game._mark == null, "cleanup releases presentation")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
