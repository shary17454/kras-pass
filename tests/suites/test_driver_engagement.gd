extends RefCounted

class Observer:
	extends "res://src/ai/brains/driver_brain.gd"
	var selected := 1
	var visible := [1, 2]
	var predicted := -1
	var destination := Vector3.ZERO

	func priority_rival() -> int:
		return selected

	func can_target(target_slot: int) -> bool:
		return target_slot in visible

	func predict(target_slot: int, _lead: float = 0.35) -> Vector3:
		predicted = target_slot
		return ctx.fighter(slot).global_position + Vector3(2 if target_slot == 1 else -2, 0, 0)

	func drive_to(target: Vector3, _reverse_when_stuck: bool = true) -> void:
		destination = target


func run(t: TestHarness, host: Node) -> void:
	t.suite("driver backoff engagement memory")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 816)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = Vector3.ZERO
		me.velocity = Vector3.ZERO
		var brain := Observer.new()
		brain.configure(0, scene.ctx, difficulty, 816)
		brain.on_round_start()
		brain.strategy = 1.0
		brain.decide(0.1)
		t.equal(brain._state, "backoff", "tier %d starts run-up from the close observed rival" % difficulty)
		brain.selected = 2
		brain.decide(0.1)
		t.equal(brain.predicted, 1, "tier %d backoff retains its observed engagement" % difficulty)
		t.ok(brain.destination.x < me.global_position.x, "tier %d backs away from the original rival" % difficulty)
		brain.visible = [2]
		brain.decide(0.1)
		t.equal(brain.predicted, 2, "tier %d lost perception cancels stale engagement" % difficulty)
		brain._state = "backoff"
		brain._state_timer = 0.9
		brain.on_round_start()
		t.equal(brain._state, "hunt", "tier %d new round clears maneuver state" % difficulty)
		brain._state = "backoff"
		brain.configure(0, scene.ctx, difficulty, 817)
		t.equal(brain._state, "hunt", "tier %d reconfiguration clears maneuver state" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
