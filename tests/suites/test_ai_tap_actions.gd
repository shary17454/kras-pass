extends RefCounted

class StationaryGunner:
	extends "res://src/ai/brains/gunner_brain.gd"
	func drive_to(_target: Vector3, _reverse_when_stuck: bool = true) -> void:
		move = Vector2.ZERO
	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true


class StationaryMelee:
	extends AIBrain
	func decide(_delta: float) -> void:
		maybe_attack(1)
	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true


class StationarySiege:
	extends "res://src/ai/brains/siege_brain.gd"
	func steer_to(_target: Vector3, _urgency: float = 1.0) -> void:
		move = Vector2.ZERO
	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true


class StationaryArmedRacer:
	extends "res://src/ai/brains/racer_armed_brain.gd"
	func drive_to(_target: Vector3, _reverse_when_stuck: bool = true) -> void:
		move = Vector2.ZERO


class StationaryBossWeakpoint:
	extends "res://src/ai/brains/boss_hunter_brain.gd"
	func steer_to(_target: Vector3, _urgency: float = 1.0) -> void:
		move = Vector2.ZERO


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
	await _test_melee(t, host)
	await _test_siege(t, host)
	await _test_armed_race(t, host)
	await _test_boss_weakpoint(t, host)


func _test_boss_weakpoint(t: TestHarness, host: Node) -> void:
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_dreadnought", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 857)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.ctx.observation_camera = null
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = scene.controller._vent.global_position + Vector3(0, -1.4, -1.8)
		me.facing = Vector3(0, 0, 1)
		for slot in [1, 2, 3]:
			scene.ctx.fighter(slot).hide()
		var brain := StationaryBossWeakpoint.new()
		brain.controller = scene.controller
		brain.configure(0, scene.ctx, difficulty, 857)
		brain.on_round_start()
		brain.reaction_time = 0.0
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		brain.attack_chance = 1.0
		var health: float = scene.controller.boss_health
		var edges := 0
		for tick in 181:
			brain.tick(1.0 / 60.0)
			InputRouter._physics_process(1.0 / 60.0)
			var frame := InputRouter.frame(0)
			if frame.just_pressed(InputFrame.Btn.ATTACK):
				edges += 1
			me._advance_timers(1.0 / 60.0)
			me._handle_buttons(frame)
			scene.controller._check_vent_hits(1.0 / 60.0)
		var damage: float = health - scene.controller.boss_health
		t.ok(edges >= 10, "tier %d repeated weakpoint decisions create press edges" % difficulty)
		t.ok(damage >= 90.0, "tier %d actual vent takes damage after a second swing" % difficulty)
		t.ok(damage <= 135.0, "tier %d weakpoint requests preserve vent cooldown" % difficulty)
		t.near(damage, float(scene.ctx.scores[0]), 0.001, "tier %d vent damage and credited score agree" % difficulty)
		brain._publish()
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d weakpoint request is released" % difficulty)
		brain.attack_chance = 0.0
		brain.tick(1.0)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d weakpoint request retains attack probability" % difficulty)
		brain.attack_chance = 1.0
		scene.controller._vent.hide()
		brain.tick(1.0)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d cannot attack a hidden weakpoint" % difficulty)
		scene.controller._vent.show()
		brain.reaction_time = 0.8
		brain.on_round_start()
		brain.tick(0.1)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d weakpoint acquisition must earn reaction delay" % difficulty)
		brain.reaction_time = 0.0
		brain.on_round_start()
		me.global_position += Vector3(0, 0, -10)
		brain.tick(1.0)
		InputRouter._physics_process(0.0)
		t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d cannot attack a weakpoint outside range" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _test_armed_race(t: TestHarness, host: Node) -> void:
	for difficulty in 4:
		for item in range(1, 5):
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": MatchConfig.build("sabaq_sawarikh", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 853)})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			var brain := StationaryArmedRacer.new()
			brain.controller = scene.controller
			brain.configure(0, scene.ctx, difficulty, 853)
			brain.on_round_start()
			brain.reaction_time = 0.0
			brain.decision_interval = 0.1
			brain.mistake_chance = 0.0
			brain.input_noise = 0.0
			brain.strategy = 0.0
			brain.press(InputFrame.Btn.ATTACK)
			brain._publish()
			InputRouter._physics_process(0.0)
			var uses := 0
			for tick in 181:
				if scene.controller.item_of(0) == 0 and uses < 3:
					scene.controller.held[0] = item
				brain.tick(1.0 / 60.0)
				InputRouter._physics_process(1.0 / 60.0)
				var held: int = scene.controller.item_of(0)
				scene.controller._tick_items(1.0 / 60.0)
				if held != 0 and scene.controller.item_of(0) == 0:
					uses += 1
				if uses == 3:
					break
			t.equal(uses, 3, "tier %d item %d can consume consecutive pickups after a held action" % [difficulty, item])
			brain._publish()
			InputRouter._physics_process(0.0)
			t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "tier %d item %d request is not stuck held" % [difficulty, item])
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame


func _test_siege(t: TestHarness, host: Node) -> void:
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("base_siege", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 851)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.ctx.observation_camera = null
		var me: Fighter = scene.ctx.fighter(0)
		var base: Dictionary = scene.controller._bases[1]
		me.global_position = base.node.global_position + Vector3(0, 1.3, -2.5)
		me.facing = Vector3(0, 0, 1)
		for slot in [1, 2, 3]:
			scene.ctx.fighter(slot).hide()
		var brain := StationarySiege.new()
		brain.controller = scene.controller
		brain.configure(0, scene.ctx, difficulty, 851)
		brain.on_round_start()
		brain.reaction_time = 0.0
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		var edges := 0
		for tick in 181:
			brain.tick(1.0 / 60.0)
			InputRouter._physics_process(1.0 / 60.0)
			var frame := InputRouter.frame(0)
			if frame.just_pressed(InputFrame.Btn.ATTACK):
				edges += 1
			me._advance_timers(1.0 / 60.0)
			scene.controller.tick(1.0 / 60.0)
			me._handle_buttons(frame)
		var hits: int = base.hits
		t.ok(edges >= 10, "tier %d repeated crystal attacks create input edges" % difficulty)
		t.ok(hits >= 3, "tier %d actual crystal takes repeated attack damage" % difficulty)
		t.ok(hits <= 6, "tier %d crystal attacks respect Fighter cooldown" % difficulty)
		t.near(base.health, scene.controller.BASE_HEALTH - hits * scene.controller.HIT_DAMAGE, 0.001, "tier %d crystal damage per swing is unchanged" % difficulty)
		t.equal(scene.controller._bases[0].hits, 0, "tier %d cannot damage its own crystal" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _test_melee(t: TestHarness, host: Node) -> void:
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("duel_pit", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 849)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = Vector3(0, 1, 0)
		me.facing = Vector3(0, 0, 1)
		scene.ctx.fighter(1).global_position = Vector3(0, 1, 2)
		scene.ctx.fighter(2).hide()
		scene.ctx.fighter(3).hide()
		var brain := StationaryMelee.new()
		brain.controller = scene.controller
		brain.configure(0, scene.ctx, difficulty, 849)
		brain.on_round_start()
		brain.reaction_time = 0.0
		brain.decision_interval = 0.1
		brain.mistake_chance = 0.0
		brain.input_noise = 0.0
		brain.attack_chance = 1.0
		_test_melee_guards(t, brain, scene, difficulty)
		var edges := 0
		var swings := 0
		for tick in 181:
			brain.tick(1.0 / 60.0)
			InputRouter._physics_process(1.0 / 60.0)
			var frame := InputRouter.frame(0)
			if frame.just_pressed(InputFrame.Btn.ATTACK):
				edges += 1
			me._advance_timers(1.0 / 60.0)
			var before: float = me._attack_cd
			me._handle_buttons(frame)
			if before <= 0.0 and me._attack_cd > 0.0:
				swings += 1
		t.ok(edges >= 10, "tier %d repeated melee decisions create new press edges" % difficulty)
		t.ok(swings >= 3, "tier %d actual fighter can attack again after cooldown" % difficulty)
		t.ok(swings <= 6, "tier %d melee requests do not bypass cooldown" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _test_melee_guards(t: TestHarness, brain: AIBrain, scene: Node, difficulty: int) -> void:
	var me: Fighter = scene.ctx.fighter(0)
	var rival: Fighter = scene.ctx.fighter(1)
	rival.global_position = Vector3(0, 1, 10)
	brain.maybe_attack(1)
	_assert_no_melee_request(t, brain, "tier %d cannot attack outside range" % difficulty)
	rival.global_position = Vector3(0, 1, 2)
	rival.hide()
	brain.maybe_attack(1)
	_assert_no_melee_request(t, brain, "tier %d cannot attack a hidden rival" % difficulty)
	rival.show()
	me.can_attack = false
	brain.maybe_attack(1)
	_assert_no_melee_request(t, brain, "tier %d respects disabled attacks" % difficulty)
	me.can_attack = true
	brain.attack_chance = 0.0
	brain.maybe_attack(1)
	_assert_no_melee_request(t, brain, "tier %d retains attack probability" % difficulty)
	brain.attack_chance = 1.0
	brain.reaction_time = 0.8
	brain.on_round_start()
	brain.maybe_attack(1)
	_assert_no_melee_request(t, brain, "tier %d must earn target reaction delay" % difficulty)
	brain.reaction_time = 0.0
	brain.on_round_start()


func _assert_no_melee_request(t: TestHarness, brain: AIBrain, message: String) -> void:
	brain._publish_output(Vector2.ZERO)
	InputRouter._physics_process(0.0)
	t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), message)


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
