extends RefCounted

class PickupProbe extends Node3D:
	var queries := 0
	var available := true
	func is_available() -> bool:
		queries += 1
		return available


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI visible targets")
	var cfg := MatchConfig.build("ring_rumble", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 119)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
	var brain := AIBrain.new()
	brain.configure(0, scene.ctx, 3, 119)
	brain.reaction_time = 0.0
	brain.edge_awareness = 1.0
	var hidden: Fighter = scene.ctx.fighter(1)
	var visible: Fighter = scene.ctx.fighter(2)
	var far: Fighter = scene.ctx.fighter(3)
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	hidden.global_position = Vector3(1, 1, 0)
	visible.global_position = Vector3(3, 1, 0)
	far.global_position = Vector3(6, 1, 0)
	hidden.hide()
	scene.ctx.scores[1] = 100
	scene.ctx.scores[2] = 50
	scene.ctx.scores[3] = 1
	t.equal(brain.nearest_rival(), 2, "hidden nearest opponent cannot become a target")
	t.equal(brain.leader_rival(), 2, "hidden leader cannot reveal a target location")
	hidden.global_position = scene.ctx.arena_center() + Vector3(scene.arena.def.radius - 0.5, 1, 0)
	visible.global_position = scene.ctx.arena_center() + Vector3(scene.arena.def.radius - 1.5, 1, 0)
	far.global_position = scene.ctx.arena_center() + Vector3.UP
	t.equal(brain.edge_pressured_rival(2.0), 2, "hidden edge position cannot influence targeting")
	hidden.show()
	hidden.global_position = Vector3(5, 1, 0)
	hidden.velocity = Vector3(2, 0, 0)
	brain._record_history()
	brain._time = 0.1
	hidden.hide()
	hidden.global_position = Vector3(99, 1, 0)
	hidden.velocity = Vector3(40, 0, 0)
	brain._record_history()
	brain._time = 0.2
	t.equal(brain.perceive(1), Vector3(5, 1, 0), "hidden movement cannot update last observed position")
	t.equal(brain._perceived_velocity(1), Vector3.ZERO, "hidden velocity cannot leak into prediction")
	brain.on_round_start()
	t.equal(brain.perceive(1), Vector3.ZERO, "unobserved hidden player does not expose a live fallback")
	t.equal(brain._perceived_velocity(1), Vector3.ZERO, "unobserved hidden velocity has no live fallback")
	hidden.show()
	hidden.global_position = Vector3(7, 1, 0)
	brain._record_history()
	t.equal(brain.perceive(1), Vector3(7, 1, 0), "visible player becomes observable again")
	brain.on_round_start()
	for index in AIBrain.HISTORY_CAP + 4:
		brain._time = float(index) * 0.05
		hidden.global_position = Vector3(index, 1, 0)
		brain._record_history()
	hidden.hide()
	hidden.global_position = Vector3(9999, 1, 0)
	brain._time += 0.05
	brain._record_history()
	brain._time += 0.05
	t.equal(brain.perceive(1), Vector3(AIBrain.HISTORY_CAP + 3, 1, 0), "wrapped history retains newest last-seen position")
	t.equal(brain._history_count, AIBrain.HISTORY_CAP, "visibility history remains bounded")
	hidden.mods["shield"] = 1.0
	t.ok(not brain.is_empowered(1), "hidden powerup state cannot be inspected")
	brain.attack_chance = 1.0
	brain.bits = 0
	brain.maybe_attack(1, 100.0)
	t.equal(brain.bits, 0, "hidden rival cannot trigger an attack decision")
	hidden.show()
	brain.on_round_start()
	brain._time = 0.0
	hidden.global_position = Vector3(9, 1, 0)
	brain._record_history()
	brain._time = 0.3
	hidden.global_position = Vector3(19, 1, 0)
	brain._record_history()
	brain._time = 0.4
	brain.reaction_time = 0.2
	t.equal(brain.perceive(1), Vector3(9, 1, 0), "visible target retains configured reaction delay")
	var parent := Node3D.new()
	scene.add_child(parent)
	parent.hide()
	var probes: Array[PickupProbe] = []
	for index in 4:
		var probe := PickupProbe.new()
		if index == 1: parent.add_child(probe)
		else: scene.add_child(probe)
		probe.add_to_group("test_ai_visible_pickups")
		probe.global_position = Vector3(0.2 + index, 1, 0)
		probes.append(probe)
	probes[0].hide()
	probes[2].available = false
	t.equal(brain.nearest_in_group("test_ai_visible_pickups", host.get_tree()), probes[3], "hidden or unavailable pickups cannot become targets")
	t.equal(probes[0].queries, 0, "hidden pickup availability is never queried")
	t.equal(probes[1].queries, 0, "hidden parent suppresses child availability queries")
	probes[3].hide()
	t.equal(brain.nearest_in_group("test_ai_visible_pickups", host.get_tree()), null, "no observable pickup returns no target")
	probes[3].show()
	probes[3].queue_free()
	t.equal(brain.nearest_in_group("test_ai_visible_pickups", host.get_tree()), null, "queued pickup cannot become a target")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
