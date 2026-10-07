extends RefCounted

class Observer:
	extends "res://src/ai/brains/tank_brain.gd"
	var clear_view := true
	var destination := Vector3.INF

	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return clear_view

	func drive_to(target: Vector3, _reverse_when_stuck: bool = true) -> void:
		destination = target


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank weapon crate reaction and visible positions")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("tank_arena", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 814)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
			fighter.hide()
		scene.ctx.fighter(0).show()
		scene.ctx.fighter(0).global_position = Vector3(0, 100, 0)
		scene.ctx.observation_camera = null
		for crate in scene.controller.crates:
			crate.node.hide()
		var crate: Node3D = scene.controller.crates[0].node
		var p0 := Vector3(5, 100, 0)
		var p1 := Vector3(10, 100, 0)
		crate.global_position = p0
		crate.show()
		var brain := Observer.new()
		brain.configure(0, scene.ctx, difficulty, 814)
		brain.controller = scene.controller
		brain.on_round_start()
		brain._time = 10.0
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "tier %d first crate waits for reaction" % difficulty)
		brain._time += brain.reaction_time - 0.0001
		t.equal(brain._visible_weapon_crate(), null, "tier %d crate is not usable early" % difficulty)
		brain._time = 10.0 + brain.reaction_time
		crate.global_position = p1
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), crate, "tier %d mature visible crate can be selected" % difficulty)
		brain.decide(0.01)
		t.equal(brain.destination, p0, "tier %d navigation uses delayed position not live transform" % difficulty)
		crate.hide()
		t.equal(brain._visible_weapon_crate(), null, "hidden crate is not actionable")
		crate.show()
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "reappearing crate earns fresh reaction credit")
		brain._time += brain.reaction_time
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), crate, "reappearing crate eventually becomes usable")
		brain.clear_view = false
		t.equal(brain._visible_weapon_crate(), null, "blocked crate is not actionable")
		brain.clear_view = true
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "unblocked crate earns fresh reaction credit")
		brain._time += brain.reaction_time
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), crate, "unblocked crate becomes usable after delay")
		brain.on_round_start()
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "round restart clears crate observation credit")
		brain._time += brain.reaction_time
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), crate, "new round can acquire crate again")
		brain.configure(0, scene.ctx, difficulty, 815)
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "reconfiguration clears crate observation credit")
		brain.reaction_time = 0.0
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), crate, "zero delay diagnostics remain immediate")
		for sample in 100:
			brain._time += 0.05
			brain._record_history()
		t.ok(brain._crate_history[crate.get_instance_id()].size() <= brain.HISTORY_CAP, "crate observation samples remain bounded")
		scene.controller.crates[0].cooldown = 9.0
		t.equal(brain._visible_weapon_crate(), null, "collected crate cannot remain actionable")
		t.equal(brain._crate_history.size(), 0, "unavailable crate releases observation storage")
		scene.controller.crates[0].cooldown = 0.0
		brain.reaction_time = 0.3
		brain._record_history()
		t.equal(brain._visible_weapon_crate(), null, "respawned crate requires new observation delay")
		scene.controller.ammo[0] = 1
		t.equal(brain._visible_weapon_crate(), null, "armed player does not request weapon crate")
		t.equal(brain._crate_history.size(), 0, "armed player releases unnecessary crate history")
		scene.controller.ammo[0] = 0
		var physical = load("res://src/ai/brains/tank_brain.gd").new()
		physical.configure(0, scene.ctx, difficulty, 814)
		physical.controller = scene.controller
		physical.reaction_time = 0.0
		t.equal(physical._visible_weapon_crate(), crate, "actual raycaster sees unobstructed crate")
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1, 4, 4)
		shape.shape = box
		wall.add_child(shape)
		scene.add_child(wall)
		wall.global_position = Vector3(5, 101, 0)
		await host.get_tree().physics_frame
		t.equal(physical._visible_weapon_crate(), null, "actual collision cover blocks crate acquisition")
		t.equal(physical._crate_history.size(), 0, "actual blocked ray clears observation credit")
		wall.free()
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
