extends RefCounted

class Observer:
	extends "res://src/ai/brains/tank_brain.gd"
	var clear_view := true
	var destination := Vector3.INF

	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return clear_view

	func drive_to(target: Vector3, _reverse_when_stuck: bool = true) -> void:
		destination = target


class EngagementObserver:
	extends "res://src/ai/brains/tank_brain.gd"
	var target_position := Vector3.ZERO

	func priority_rival() -> int:
		return 1

	func predict(_target_slot: int, _lead: float = 0.35) -> Vector3:
		return target_position

	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true

	func _visible_weapon_crate() -> Node3D:
		return null


class FiringObserver:
	extends Observer
	var seen := Vector3.ZERO
	var seen_velocity := Vector3.ZERO

	func priority_rival() -> int:
		return 1

	func perceive(_target_slot: int) -> Vector3:
		return seen

	func _perceived_velocity(_target_slot: int) -> Vector3:
		return seen_velocity

	func _visible_weapon_crate() -> Node3D:
		return null


func run(t: TestHarness, host: Node) -> void:
	await _check_projectile_lead(t, host)
	await _check_close_target_turn(t, host)
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


func _check_close_target_turn(t: TestHarness, host: Node) -> void:
	t.suite("tank close engagement steering follows actual drive physics")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("tank_arena", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 1604242)})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var me: Fighter = scene.ctx.fighter(0)
	me.global_position = Vector3(0, 100, 0)
	for difficulty in 4:
		var brain := EngagementObserver.new()
		brain.configure(0, scene.ctx, difficulty, 1604242)
		brain.controller = scene.controller
		brain.accuracy = 1.0
		for yaw in [0.0, PI / 2.0, PI, -PI / 2.0]:
			for angle in [-2.6, 2.6]:
				for distance in [2.0, 6.0]:
					me._steer = yaw
					me.facing = Vector3(sin(yaw), 0, cos(yaw))
					me.velocity = Vector3.ZERO
					var target_yaw: float = yaw + angle
					brain.target_position = me.global_position + Vector3(sin(target_yaw), 0, cos(target_yaw)) * distance
					brain.decide(1.0 / 60.0)
					var before := absf(wrapf(target_yaw - me._steer, -PI, PI))
					me._integrate_drive(Vector3(brain.move.x, 0, brain.move.y), 1.0 / 60.0)
					var after := absf(wrapf(target_yaw - me._steer, -PI, PI))
					t.ok(after < before, "tier %d close target turn reduces yaw error at distance %.1f" % [difficulty, distance])
					t.ok(brain.move.y > 0.0 if distance < 3.0 else is_zero_approx(brain.move.y), "muzzle clearance still reverses or holds as intended")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _check_projectile_lead(t: TestHarness, host: Node) -> void:
	t.suite("tank firing lead uses delayed cues and own shell speed")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("tank_arena", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 1604242)})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var me: Fighter = scene.ctx.fighter(0)
	me.global_position = Vector3(0, 100, 0)
	me.facing = Vector3.RIGHT
	scene.ctx.fighter(1).velocity = Vector3(99, 0, -99)
	for difficulty in 4:
		var brain := FiringObserver.new()
		brain.configure(0, scene.ctx, difficulty, 1604242)
		brain.controller = scene.controller
		brain.prediction = 1.0
		brain.seen_velocity = Vector3(0, 0, 6)
		for distance in [6.0, 12.0, 20.0]:
			brain.seen = me.global_position + Vector3.RIGHT * distance
			for kind in scene.controller.SHELL_SPEED.size():
				scene.controller.shell_types[0] = kind
				scene.controller.ammo[0] = 3
				brain.decide(1.0 / 60.0)
				var lead: float = brain.destination.z / 6.0
				var flight: float = lead - brain.reaction_time
				var travel: float = (brain.destination - me.global_position - me.facing * 1.6).length()
				t.near(travel, scene.controller.SHELL_SPEED[kind] * flight, 0.001, "tier %d shell %d intercept travel at %.1f" % [difficulty, kind, distance])
				t.near(brain.destination.x, brain.seen.x, 0.001, "live hidden velocity never changes observed trajectory")
		brain.prediction = 0.0
		brain.decide(1.0 / 60.0)
		t.equal(brain.destination, brain.seen, "no prediction retains delayed position")
		brain.prediction = 1.0
		brain.seen_velocity = Vector3.ZERO
		brain.decide(1.0 / 60.0)
		t.equal(brain.destination, brain.seen, "stationary target is never over-led")
		brain.seen_velocity = Vector3(0, 100, 6)
		brain.decide(1.0 / 60.0)
		t.near(brain.destination.y, brain.seen.y, 0.001, "vertical velocity cannot distort ground aim")
		brain.seen_velocity = Vector3(40, 0, 0)
		brain.decide(1.0 / 60.0)
		t.ok(brain.destination.is_finite(), "unreachable target keeps finite fallback")
		t.ok(brain.destination.x <= brain.seen.x + 40.0 * (brain.reaction_time + 2.0) + 0.00001, "unreachable prediction horizon remains bounded within float precision")
		brain.seen_velocity = Vector3(18, 0, 0)
		brain.decide(1.0 / 60.0)
		t.ok(brain.destination.is_finite(), "equal projectile and target speed keeps finite fallback")
	scene.controller.ammo[0] = 0
	t.equal(scene.controller.projectile_speed_for(0), 22.0, "empty special ammo uses standard projectile speed")
	scene.ctx.config.rules["tank_variant"] = "ricochet"
	t.equal(scene.controller.projectile_speed_for(0), 26.0, "ricochet-only rules override empty inventory")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
