extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("tide simultaneous elimination")
	var cfg := MatchConfig.build("rising_tide", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	scene.phase = MatchPhase.P.PLAYING
	var water = scene.arena._water
	water.level = 50.0
	water._age = 12.0
	water.check(scene.ctx.fighters)
	t.equal(scene.controller.compute_scores(), [2, 2, 2, 2], "same water tick ties every slot")
	for fighter in scene.ctx.fighters:
		scene.ctx.revive(fighter.slot)
		fighter.respawn_at(Vector3.ZERO)
	scene.controller.on_round_start()
	water._age = 1.0
	scene.controller.on_fighter_fell(3)
	water._age = 2.0
	scene.controller.on_fighter_fell(2)
	scene.controller.on_fighter_fell(0)
	t.equal(scene.controller.compute_scores(), [4, 8, 4, 2], "different ages rank while same age ties regardless of slot order")
	water._age = 3.0
	scene.controller.on_fighter_fell(3)
	t.equal(scene.controller.compute_scores(), [4, 8, 4, 2], "duplicate elimination cannot improve a victim's rank")
	scene.ctx.details[0]["knockouts"] = 1
	var scored: Array[int] = scene.controller.compute_scores()
	t.equal(scored[0], 4 + scene.controller.survival_knockout_weight, "legitimate knockout reward preserved")
	scene.ctx.details[0]["knockouts"] = 10
	var rewarded: Array[int] = scene.controller.compute_scores()
	t.ok(rewarded[1] > rewarded[0], "survivor still wins over an eliminated knockout leader")
	t.equal(rewarded[0], 4 + 10 * scene.controller.survival_knockout_weight, "survivor priority does not erase hunter reward")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
