extends RefCounted

class Observer:
	extends "res://src/ai/brains/tank_brain.gd"
	var target := Vector3.ZERO

	func priority_rival() -> int:
		return 1

	func _firing_target(_rival: int) -> Vector3:
		return target

	func _visible_weapon_crate() -> Node3D:
		return null

	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("stationary tank aim keeps forward steering polarity")
	var config := MatchConfig.build("tank_arena", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 510169)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": config})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var me: Fighter = scene.ctx.fighter(0)
	var origin: Vector3 = scene.arena.global_position
	for difficulty in 4:
		for degrees in [-170.0, -150.0, 150.0, 170.0]:
			var brain := Observer.new()
			brain.configure(0, scene.ctx, difficulty, 510169)
			brain.controller = scene.controller
			var angle := deg_to_rad(degrees)
			brain.target = origin + Vector3(sin(angle), 0, cos(angle)) * 8.0
			me.global_position = origin
			me.facing = Vector3.BACK
			me._steer = 0.0
			me.velocity = Vector3.ZERO
			brain.decide(1.0 / 60.0)
			var label := "tier%d/angle%d" % [difficulty, int(degrees)]
			t.equal(brain.move.y, 0.0, label + " holds firing distance without reversing")
			me._integrate_drive(Vector3(brain.move.x, 0, brain.move.y), 1.0 / 60.0)
			t.ok(absf(wrapf(angle - me._steer, -PI, PI)) < absf(angle),
				label + " actual chassis turns toward the rear target")
			for frame in 360:
				brain.decide(1.0 / 60.0)
				me._integrate_drive(Vector3(brain.move.x, 0, brain.move.y), 1.0 / 60.0)
			t.ok(me.facing.dot((brain.target - origin).normalized()) > 0.97,
				label + " does not oscillate facing away from its target")
			t.ok(Vector2(me.velocity.x, me.velocity.z).length() < 0.0001,
				label + " aiming does not gain movement speed")
			brain.controller = null
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
