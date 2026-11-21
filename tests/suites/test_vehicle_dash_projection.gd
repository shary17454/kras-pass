extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI dash safety uses actual vehicle heading")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 819)})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var me: Fighter = scene.ctx.fighter(0)
	var arena: Arena = scene.ctx.arena
	me.global_position = arena.global_position + Vector3(arena.def.radius - 4.0, 0, 0)
	var brain := AIBrain.new()
	brain.configure(0, scene.ctx, 3, 819)
	brain.controller = scene.controller
	brain.dash_chance = 1.0
	brain.decision_interval = 1.0
	brain.edge_awareness = 1.0
	me.facing = Vector3.RIGHT
	brain.move = Vector2(0, -1)
	brain.maybe_dash()
	t.equal(_published_dash(brain), 0, "outward vehicle nose rejects a lethal dash even when throttle vector looks safe")
	brain.bits = 0
	me.facing = Vector3.LEFT
	brain.move = Vector2(1, -1)
	brain.maybe_dash()
	t.ok(_published_dash(brain) != 0, "inward nose permits dash despite an outward steering input")
	brain.bits = 0
	me.facing = Vector3.RIGHT
	brain.move = Vector2.ZERO
	brain.maybe_dash()
	t.equal(_published_dash(brain), 0, "stationary vehicle still projects its nose direction")
	brain.bits = 0
	scene.controller.eliminate_on_fall = false
	brain.maybe_dash()
	t.ok(_published_dash(brain) != 0, "respawn tracks retain their existing unrestricted boost policy")
	for mode in [Fighter.Locomotion.WALK, Fighter.Locomotion.DRIVE, Fighter.Locomotion.FLOAT]:
		me.locomotion = mode
		me.facing = Vector3.LEFT
		for input_move: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2(0, -1), Vector2(1, 1)]:
			var expected := Vector3(input_move.x, 0, input_move.y)
			if mode == Fighter.Locomotion.DRIVE or expected.length_squared() < 0.05:
				expected = me.facing
			expected = expected.normalized()
			t.equal(me.dash_direction(input_move), expected, "mode %d projection preserves actor direction for %s" % [mode, input_move])
			me.charge = 1.0
			me._impulse = Vector3.ZERO
			var frame := InputFrame.new()
			frame.move = input_move
			me._do_dash(frame)
			t.ok(me._impulse.normalized().distance_to(expected) < 0.00001, "mode %d real impulse matches safety projection" % mode)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _published_dash(brain: AIBrain) -> int:
	brain._publish_output(brain.move)
	return int(InputRouter._virtual_pending[brain.slot].bits) & InputFrame.Btn.DASH
