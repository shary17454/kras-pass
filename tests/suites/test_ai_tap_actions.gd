extends RefCounted

class StationaryGunner:
	extends "res://src/ai/brains/gunner_brain.gd"
	func drive_to(_target: Vector3, _reverse_when_stuck: bool = true) -> void:
		move = Vector2.ZERO
	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI one-shot action requests")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("turret_duel", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 838)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
		scene.ctx.fighter(0).facing = Vector3(0, 0, 1)
		scene.ctx.fighter(1).global_position = Vector3(0, 1, 10)
		scene.ctx.fighter(2).hide()
		scene.ctx.fighter(3).hide()
		var brain := StationaryGunner.new()
		brain.configure(0, scene.ctx, difficulty, 838)
		brain.on_round_start()
		brain.reaction_time = 0.0
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		brain.attack_chance = 1.0
		var clicks := 0
		var shots := 0
		for tick in 181:
			InputRouter._physics_process(1.0 / 60.0)
			if scene.controller.wants_fire(InputRouter.frame(0)):
				clicks += 1
			var before: float = scene.controller._cooldowns[0]
			scene.controller.tick(1.0 / 60.0)
			if before <= 0.0 and scene.controller._cooldowns[0] > 0.0:
				shots += 1
			brain.tick(1.0 / 60.0)
		t.ok(clicks >= 10, "tier %d repeated shooting decisions create repeated input edges" % difficulty)
		t.ok(shots >= 3, "tier %d actual controller can fire again after reload" % difficulty)
		t.ok(shots <= 4, "tier %d one-shot requests cannot bypass weapon cooldown" % difficulty)
		if difficulty == 3:
			_test_publication(t, scene)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	await _test_bomber(t, host)


func _test_bomber(t: TestHarness, host: Node) -> void:
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("fawda", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 847)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
		scene.ctx.fighter(1).global_position = Vector3(0, 1, 3)
		scene.ctx.fighter(2).hide()
		scene.ctx.fighter(3).hide()
		var brain = load("res://src/ai/brains/bomber_brain.gd").new()
		brain.controller = scene.controller
		brain.configure(0, scene.ctx, difficulty, 847)
		brain.on_round_start()
		brain.reaction_time = 0.0
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		# A prior shove may still hold ATTACK when a bomb is picked up.
		brain.press(InputFrame.Btn.ATTACK)
		brain._publish()
		InputRouter._physics_process(0.0)
		var throws := 0
		for tick in 181:
			if scene.ctx.fighter(0).carrying == 0 and throws < 3:
				scene.controller._drop_bomb()
				var bomb: Dictionary = scene.controller._bombs.back()
				bomb.held = 0
				bomb.node.global_position = scene.ctx.fighter(0).global_position
				scene.ctx.fighter(0).carrying = 1
			brain.tick(1.0 / 60.0)
			InputRouter._physics_process(1.0 / 60.0)
			var held: int = scene.ctx.fighter(0).carrying
			scene.controller._read_throws()
			if held > 0 and scene.ctx.fighter(0).carrying == 0:
				throws += 1
			if throws == 3:
				break
		t.equal(throws, 3, "tier %d can throw consecutive pickups after a held shove" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _test_publication(t: TestHarness, scene: Node) -> void:
	var brains: Array = [AIBrain.new(),
		load("res://src/ai/brains/zone_brain.gd").new(),
		load("res://src/ai/brains/boss_hunter_brain.gd").new()]
	for brain in brains:
		InputRouter.clear_slot(0)
		InputRouter.assign_virtual(0)
		brain.configure(0, scene.ctx, 3, 838)
		brain.on_round_start()
		brain.press(InputFrame.Btn.JUMP)
		brain.tap(InputFrame.Btn.ATTACK)
		brain._publish_output(Vector2.ZERO)
		InputRouter._physics_process(0.0)
		t.ok(InputRouter.frame(0).just_pressed(InputFrame.Btn.ATTACK), "tap reaches virtual input as a new press")
		t.ok(InputRouter.frame(0).held(InputFrame.Btn.JUMP), "tap can coexist with a held action")
		brain._publish_output(Vector2.ZERO)
		InputRouter._physics_process(0.0)
		t.ok(InputRouter.frame(0).just_released(InputFrame.Btn.ATTACK), "tap is released on next publication")
		t.ok(InputRouter.frame(0).held(InputFrame.Btn.JUMP), "ordinary press retains held semantics")
		brain.tap(InputFrame.Btn.ATTACK)
		brain._publish_output(Vector2.ZERO)
		InputRouter._physics_process(0.0)
		t.ok(InputRouter.frame(0).just_pressed(InputFrame.Btn.ATTACK), "a later tap creates another rising edge")
		brain.tap(InputFrame.Btn.ATTACK)
		brain.on_round_start()
		brain._publish_output(Vector2.ZERO)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "new round discards pending taps")
		brain.tap(InputFrame.Btn.ATTACK)
		brain.configure(0, scene.ctx, 3, 839)
		brain._publish_output(Vector2.ZERO)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "reconfiguration discards pending taps")
