extends RefCounted

class RamObserver:
	extends "res://src/ai/brains/driver_brain.gd"
	var observed := Vector3(0, 0, 6)
	var visible := true
	var requests := 0

	func priority_rival() -> int:
		return 1 if visible else -1

	func predict(_target_slot: int, _lead: float = 0.35) -> Vector3:
		return observed

	func maybe_dash(_chance_scale: float = 1.0) -> void:
		requests += 1

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

	t.suite("driver ram commitment alignment")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 816)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = Vector3.ZERO
		me.velocity = Vector3(0, 0, me.top_speed * 0.8)
		var brain := RamObserver.new()
		brain.configure(0, scene.ctx, difficulty, 816)
		brain.on_round_start()
		me.facing = Vector3(0, 0, -1)
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d does not ram away from observed rival" % difficulty)
		brain.requests = 0
		me.facing = Vector3.RIGHT
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d turns before committing a sideways ram" % difficulty)
		brain.requests = 0
		me.facing = Vector3(0, 0, 1)
		brain.decide(0.1)
		t.equal(brain.requests, 1, "tier %d can commit an aligned ram" % difficulty)
		brain.requests = 0
		brain.observed = Vector3(0, 0, 11)
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d preserves ram range" % difficulty)
		brain.observed = Vector3(0, 0, 6)
		me.velocity = Vector3(0, 0, me.top_speed * 0.5)
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d preserves minimum ram speed" % difficulty)
		me.velocity = Vector3(0, 0, me.top_speed * 0.8)
		brain.visible = false
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d cannot ram an unobserved rival" % difficulty)
		brain.visible = true
		brain.observed = me.global_position
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d overlapping rival has no ram direction" % difficulty)
		me.global_position = Vector3(0, 0, scene.ctx.arena.current_radius - 1.0)
		brain.observed = me.global_position + me.facing * 6.0
		brain.decide(0.1)
		t.equal(brain.requests, 0, "tier %d edge recovery takes priority over ramming" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
