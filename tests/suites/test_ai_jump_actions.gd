extends RefCounted


class LaneRunner:
	extends "res://src/ai/brains/runner_brain.gd"
	func steer_to(_target: Vector3, _urgency: float = 1.0) -> void:
		move = Vector2.ZERO


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI jump requests on actual floor")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("hurdle_dash", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 871)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var origin := Vector3(1000, 0, 1000)
		_add_box(scene.ctx.world_root, origin + Vector3(0, -0.5, 0), Vector3(20, 1, 20))
		# Keep a real raycast obstacle visible through the entire jump arc.
		var wall := _add_box(scene.ctx.world_root, origin + Vector3(0, 5, -1.5), Vector3(10, 10, 0.2))
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = origin + Vector3.UP
		me.velocity = Vector3.ZERO
		me.control_enabled = true
		t.ok(me.can_jump, "tier %d hurdle rules enable jumping" % difficulty)
		var brain: AIBrain = LaneRunner.new()
		brain.controller = scene.controller
		brain.configure(0, scene.ctx, difficulty, 871)
		brain.on_round_start()
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		brain.dash_chance = 0.0
		var edges := 0
		var jumps := 0
		var landings := 0
		var was_airborne := false
		for tick in 361:
			await host.get_tree().physics_frame
			brain.tick(1.0 / 60.0)
			InputRouter._physics_process(1.0 / 60.0)
			var frame := InputRouter.frame(0)
			if frame.just_pressed(InputFrame.Btn.JUMP):
				edges += 1
			var grounded := me.is_on_floor()
			me.tick(frame, 1.0 / 60.0)
			if grounded and me.velocity.y > 1.0:
				jumps += 1
			if was_airborne and me.is_on_floor():
				landings += 1
			was_airborne = not me.is_on_floor()
		print("JUMP_CONTRACT tier=%d edges=%d jumps=%d landings=%d position=%s" % [difficulty, edges, jumps, landings, me.global_position])
		t.ok(edges >= 10, "tier %d persistent visible obstacle yields repeated jump edges" % difficulty)
		t.ok(jumps >= 3, "tier %d real grounded fighter can jump again after landing" % difficulty)
		t.ok(landings >= 2, "tier %d repeated jumps include actual floor contacts" % difficulty)
		t.ok(jumps <= 10, "tier %d jump requests do not launch continuously in air" % difficulty)
		wall.queue_free()
		await host.get_tree().physics_frame
		brain.tick(1.0)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.JUMP), "tier %d no raycast obstacle releases jump request" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _add_box(root: Node, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.global_position = position
	return body
