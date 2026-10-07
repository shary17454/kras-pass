extends RefCounted

const BRAINS := ["generic", "collector", "courier", "smasher", "relic"]

class Prize:
	extends Node3D
	var available := true
	var queries := 0
	func is_available() -> bool:
		queries += 1
		return available

class PrizeController:
	extends MiniGameController
	var prize: Node3D
	func crate_entries() -> Array:
		return [{"node": prize, "bomb": true}]
	func loose_relic() -> Node3D:
		return prize


func run(t: TestHarness, host: Node) -> void:
	t.suite("shared pickup first observation delay")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("gem_grab", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 917)})
	scene.set_physics_process(false)
	scene.ctx.observation_camera = null
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		fighter.hide()
	scene.ctx.fighter(0).show()
	scene.ctx.fighter(0).global_position = Vector3(0, 100, 0)
	for pickup in host.get_tree().get_nodes_in_group("pickups"):
		pickup.hide()
	var prize := Prize.new()
	prize.add_child(MeshFactory.crate(1.5, Color("#ffc46b"), Color.WHITE))
	scene.add_child(prize)
	prize.global_position = Vector3(4, 100, 0)
	prize.add_to_group("pickups")
	var controller := PrizeController.new()
	controller.prize = prize
	for difficulty in 4:
		for kind in BRAINS:
			prize.show()
			prize.available = true
			prize.global_position = Vector3(4, 100, 0)
			var brain = load("res://src/ai/brains/%s_brain.gd" % kind).new()
			brain.configure(0, scene.ctx, difficulty, 917)
			brain.controller = controller
			brain.accuracy = 1.0
			brain.on_round_start()
			brain._time = 10.0
			t.equal(_target(brain, kind, host), null, "%s tier %d new prize waits for reaction" % [kind, difficulty])
			brain._time += brain.reaction_time - 0.0001
			t.equal(_target(brain, kind, host), null, "%s tier %d cannot acquire early" % [kind, difficulty])
			brain._time = 10.0 + brain.reaction_time
			prize.global_position = Vector3(9, 100, 0)
			t.equal(_target(brain, kind, host), prize, "%s tier %d acquires visible prize after delay" % [kind, difficulty])
			t.equal(brain.perceived_object_position(prize), Vector3(4, 100, 0), "navigation position is delayed instead of live")
			brain._time += brain.reaction_time
			t.equal(brain.perceived_object_position(prize), Vector3(9, 100, 0), "later visible motion matures after delay")
			prize.hide()
			var before := prize.queries
			t.equal(_target(brain, kind, host), null, "hidden prize cannot be selected")
			t.equal(prize.queries, before, "hidden prize availability is not read")
			prize.show()
			t.equal(_target(brain, kind, host), null, "reappearance earns fresh observation credit")
			brain._time += brain.reaction_time
			t.equal(_target(brain, kind, host), prize, "reappearing prize becomes actionable after delay")
			prize.available = false
			t.equal(_target(brain, kind, host), null, "collected prize is not actionable")
			prize.available = true
			t.equal(_target(brain, kind, host), null, "respawn earns fresh observation credit")
			brain._time += brain.reaction_time
			t.equal(_target(brain, kind, host), prize, "respawn matures after delay")
			brain.on_round_start()
			t.equal(_target(brain, kind, host), null, "restart discards earlier observation credit")
			brain._time += brain.reaction_time
			t.equal(_target(brain, kind, host), prize, "restart can reacquire visible prize")
			brain.configure(0, scene.ctx, difficulty, 918)
			brain.accuracy = 1.0
			t.equal(_target(brain, kind, host), null, "reconfiguration discards earlier observation credit")
			for sample in 100:
				brain._time += 0.05
				brain.perceived_object_position(prize)
			t.ok(brain._object_history[prize.get_instance_id()].size() <= brain.HISTORY_CAP, "each object history is bounded")
			brain.reaction_time = 0.0
			t.equal(_target(brain, kind, host), prize, "zero-delay diagnostic remains immediate")
	var observer = load("res://src/ai/brains/generic_brain.gd").new()
	observer.configure(0, scene.ctx, 3, 917)
	observer.perceived_object_position(prize)
	prize.free()
	observer._record_history()
	t.equal(observer._object_history.size(), 0, "destroyed object identity is released on the next sample")
	controller.free()
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _target(brain, kind: String, host: Node) -> Node3D:
	match kind:
		"collector": return brain._preferred_loot()
		"smasher": return brain._pick_crate()
		"relic": return brain._loose_relic()
	return brain.nearest_in_group("pickups", host.get_tree())
