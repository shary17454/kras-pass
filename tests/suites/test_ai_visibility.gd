extends RefCounted

class PickupProbe extends Node3D:
	var queries := 0
	var available := true
	func is_available() -> bool:
		queries += 1
		return available

class RaceCueProbe extends MiniGameController:
	func rival_ahead(_slot: int) -> int:
		return 1

class MagnetCueProbe extends MiniGameController:
	func magnet_ready(_slot: int) -> bool:
		return true


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
	_test_collector(t, scene)
	_test_duo(t, scene)
	_test_smasher(t, scene)
	_test_duellist(t, scene)
	_test_ball(t, scene)
	_test_courier(t, scene)
	_test_platform(t, scene)
	_test_remaining_rivals(t, scene)
	_test_keeper_balls(t, scene)
	_test_bomb_states(t, scene)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _test_collector(t: TestHarness, scene: Node) -> void:
	var collector = load("res://src/ai/brains/collector_brain.gd").new()
	collector.configure(0, scene.ctx, 3, 119)
	collector.reaction_time = 0.0
	collector.strategy = 1.0
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	for slot in range(1, 4): scene.ctx.fighter(slot).hide()
	var parent := Node3D.new()
	scene.add_child(parent)
	parent.hide()
	var probes: Array[PickupProbe] = []
	for index in 4:
		var probe := PickupProbe.new()
		if index == 1: parent.add_child(probe)
		else: scene.add_child(probe)
		probe.add_to_group("pickups")
		probe.global_position = Vector3([0.1, 0.2, 4.0, -6.0][index], 1, 0)
		probes.append(probe)
	probes[0].hide()
	scene.ctx.fighter(1).global_position = probes[2].global_position
	scene.ctx.fighter(1).show()
	collector._record_history()
	scene.ctx.fighter(1).hide()
	t.equal(collector._preferred_loot(), probes[2], "collector chooses visible loot without hidden competition")
	t.equal(probes[0].queries, 0, "collector never queries hidden pickup availability")
	t.equal(probes[1].queries, 0, "collector respects hidden pickup ancestors")
	scene.ctx.fighter(1).show()
	t.equal(collector._preferred_loot(), probes[3], "collector still avoids loot contested by a visible rival")
	scene.ctx.fighter(1).hide()
	t.equal(collector._preferred_loot(), probes[2], "hidden rival cannot keep visible loot contested")
	probes[2].available = false
	t.equal(collector._preferred_loot(), probes[3], "collector preserves visible availability checks")
	probes[3].hide()
	t.equal(collector._preferred_loot(), null, "collector has no target when observable loot is unavailable")
	probes[3].show()
	probes[3].queue_free()
	t.equal(collector._preferred_loot(), null, "collector excludes queued pickups")
	for probe in probes:
		probe.remove_from_group("pickups")
		if not probe.is_queued_for_deletion(): probe.queue_free()
	parent.queue_free()


func _test_duo(t: TestHarness, scene: Node) -> void:
	var duo = load("res://src/ai/brains/duo_brain.gd").new()
	duo.configure(0, scene.ctx, 3, 119)
	duo.controller = load("res://src/minigames/duo_clash.gd").new()
	duo.reaction_time = 0.0
	duo.edge_awareness = 1.0
	var center: Vector3 = scene.ctx.arena_center()
	for slot in 4:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).mods.clear()
	scene.ctx.fighter(0).global_position = center + Vector3.UP
	scene.ctx.fighter(1).global_position = center + Vector3(scene.arena.def.radius - 0.5, 1, 0)
	scene.ctx.fighter(1).hide()
	scene.ctx.fighter(2).global_position = center + Vector3(scene.arena.def.radius - 0.2, 1, 0)
	scene.ctx.fighter(3).global_position = center + Vector3(3, 1, 0)
	t.equal(duo._pick_target(), 3, "duo edge selection excludes hidden enemy and visible ally")
	duo.edge_awareness = 0.0
	scene.ctx.fighter(1).global_position = center + Vector3(0.1, 1, 0)
	scene.ctx.fighter(2).global_position = center + Vector3(0.05, 1, 0)
	t.equal(duo._pick_target(), 3, "duo nearest selection excludes hidden enemy and visible ally")
	scene.ctx.fighter(3).hide()
	t.equal(duo._pick_target(), -1, "duo has no target when only its ally is visible")
	scene.ctx.fighter(1).show()
	t.equal(duo._pick_target(), 1, "duo can target an enemy once visible again")
	duo.controller.free()
	duo.controller = null


func _test_smasher(t: TestHarness, scene: Node) -> void:
	var smasher = load("res://src/ai/brains/smasher_brain.gd").new()
	smasher.configure(0, scene.ctx, 3, 119)
	smasher.accuracy = 1.0
	var controller = load("res://src/minigames/crate_smash.gd").new()
	smasher.controller = controller
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	var crates: Array[Node3D] = []
	for index in 3:
		var crate := StaticBody3D.new()
		crate.add_child(MeshFactory.crate(1.5,
			Color("#3a2b3f") if index == 1 else Color("#ffc46b"), Color.WHITE))
		scene.add_child(crate)
		crate.global_position = Vector3([4.0, 1.0, 0.1][index], 1, 0)
		crates.append(crate)
		controller._crates.append({"node": crate, "bomb": index != 1})
	crates[2].hide()
	t.equal(smasher._pick_crate(), crates[0], "smasher judges rendered colour rather than contradictory bomb flags")
	t.ok(not smasher._judgements.has(crates[2].get_instance_id()), "hidden crate has no cached judgement")
	crates[2].show()
	t.equal(smasher._pick_crate(), crates[2], "newly visible safe crate becomes a target")
	smasher.on_round_start()
	t.equal(smasher._judgements.size(), 0, "new round discards crate judgements")
	for entry in controller._crates: entry["bomb"] = not bool(entry["bomb"])
	crates[2].hide()
	t.equal(smasher._pick_crate(), crates[0], "changing secret flags alone cannot change crate classification")
	smasher.accuracy = 0.0
	t.equal(smasher._pick_crate(), crates[0], "cached visible judgement is not rerolled each decision")
	smasher.on_round_start()
	t.equal(smasher._pick_crate(), crates[1], "configured classification error still applies to visible cues")
	smasher.accuracy = 1.0
	var visual: Node3D = crates[0].get_child(0)
	visual.hide()
	smasher.on_round_start()
	t.equal(smasher._pick_crate(), null, "smasher cannot classify a crate whose visual is hidden")
	visual.show()
	t.equal(smasher._pick_crate(), crates[0], "revealing the visual permits a fresh judgement")
	crates[0].queue_free()
	t.equal(smasher._pick_crate(), null, "queued safe crate cannot become a target")
	t.ok(not smasher._judgements.has(crates[0].get_instance_id()), "removed crates do not accumulate cached judgements")
	smasher.controller = null
	controller.cleanup()
	controller.free()


func _test_duellist(t: TestHarness, scene: Node) -> void:
	var duellist = load("res://src/ai/brains/duellist_brain.gd").new()
	duellist.configure(0, scene.ctx, 3, 119)
	duellist.reaction_time = 0.0
	duellist.strategy = 1.0
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	for slot in range(1, 4):
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot + 1, 1, 0)
		scene.ctx.fighter(slot).damage_percent = 20.0
	scene.ctx.fighter(1).damage_percent = 999.0
	scene.ctx.fighter(1).hide()
	scene.ctx.fighter(2).damage_percent = 80.0
	t.equal(duellist._best_target(), 2, "duellist targets visible damaged rival rather than hidden leader")
	scene.ctx.fighter(2).hide()
	t.equal(duellist._best_target(), 3, "duellist retains remaining visible target")
	scene.ctx.fighter(3).hide()
	t.equal(duellist._best_target(), -1, "duellist has no target when rivals are hidden")
	scene.ctx.fighter(1).show()
	t.equal(duellist._best_target(), 1, "duellist can target damaged rival after it reappears")


func _test_ball(t: TestHarness, scene: Node) -> void:
	var brain = load("res://src/ai/brains/ball_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 119)
	brain.reaction_time = 0.0
	var parent := Node3D.new()
	scene.add_child(parent)
	parent.hide()
	var balls: Array[GameBall] = []
	for index in 3:
		var ball := GameBall.new()
		if index == 1: parent.add_child(ball)
		else: scene.add_child(ball)
		ball.add_to_group("balls")
		balls.append(ball)
	balls[0].hide()
	t.equal(brain._ball(), balls[2], "blast bot ignores hidden and inherited-hidden balls")
	balls[2].queue_free()
	t.equal(brain._ball(), null, "blast bot ignores queued or hidden balls")
	for slot in 4:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot, 1, 0)
	brain._record_history()
	scene.ctx.fighter(1).hide()
	t.equal(brain._best_victim(Vector3(1, 1, 0)), 2, "blast bot cannot select a hidden victim at its last seen position")
	scene.ctx.fighter(2).hide()
	scene.ctx.fighter(3).hide()
	t.equal(brain._best_victim(Vector3(1, 1, 0)), -1, "blast bot has no victim when rivals are hidden")
	scene.ctx.fighter(1).show()
	t.equal(brain._best_victim(Vector3(1, 1, 0)), 1, "blast bot can select a rival after it reappears")
	for ball in balls:
		ball.remove_from_group("balls")
		if not ball.is_queued_for_deletion(): ball.queue_free()
	parent.queue_free()


func _test_courier(t: TestHarness, scene: Node) -> void:
	var brain = load("res://src/ai/brains/courier_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 119)
	brain.reaction_time = 0.0
	for slot in 4:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot, 1, 0)
		scene.ctx.fighter(slot).carrying = slot
	scene.ctx.fighter(1).carrying = 8
	scene.ctx.fighter(2).carrying = 4
	brain._record_history()
	scene.ctx.fighter(1).hide()
	t.equal(brain._richest_carrier(), 2, "courier ignores a hidden carrier's larger inventory")
	scene.ctx.fighter(2).hide()
	t.equal(brain._richest_carrier(), 3, "courier chooses the remaining visible carrier")
	scene.ctx.fighter(3).hide()
	t.equal(brain._richest_carrier(), -1, "courier has no target when all carriers are hidden")
	scene.ctx.fighter(2).show()
	scene.ctx.fighter(2).carrying = 0
	t.equal(brain._richest_carrier(), 2, "courier still falls back to a visible nearest rival")
	scene.ctx.fighter(1).show()
	t.equal(brain._richest_carrier(), 1, "courier can target a visible loaded carrier again")


func _test_platform(t: TestHarness, scene: Node) -> void:
	var brain = load("res://src/ai/brains/platform_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 119)
	brain.reaction_time = 0.0
	for slot in 4:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot * 5, 1, 0)
	var tile := ArenaTile.new()
	scene.add_child(tile)
	tile.global_position = scene.ctx.fighter(1).global_position
	brain._record_history()
	scene.ctx.fighter(1).hide()
	t.ok(not brain._occupied(tile), "hidden rival's last seen position cannot reserve a tile")
	scene.ctx.fighter(1).show()
	t.ok(brain._occupied(tile), "visible rival still marks a tile occupied")
	var other := ArenaTile.new()
	scene.add_child(other)
	other.global_position = tile.global_position + Vector3(4, 0, 0)
	var tiles: Array[ArenaTile] = scene.arena.tiles.duplicate()
	scene.arena.tiles.clear()
	scene.arena.tiles.append(tile)
	scene.arena.tiles.append(other)
	tile.hide()
	t.equal(brain._pick_tile(scene.arena, tile.global_position), other, "hidden solid floor cannot become a platform target")
	t.equal(brain._solid_neighbours(scene.arena, other), 0.0, "hidden floor cannot improve a tile's neighbour score")
	other.hide()
	t.equal(brain._pick_tile(scene.arena, tile.global_position), null, "platform bot has no target when all tiles are hidden")
	brain._target_tile = tile
	brain.decide(0.0)
	t.equal(brain._target_tile, null, "platform bot discards a cached tile once it becomes hidden")
	other.show()
	brain.decide(0.0)
	t.equal(brain._target_tile, other, "platform bot resumes targeting visible solid ground")
	scene.arena.tiles = tiles
	tile.queue_free()
	other.queue_free()


func _test_remaining_rivals(t: TestHarness, scene: Node) -> void:
	for slot in 4:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot, 1, 0)
	var zone = load("res://src/ai/brains/zone_brain.gd").new()
	var bomber = load("res://src/ai/brains/bomber_brain.gd").new()
	var climber = load("res://src/ai/brains/climber_brain.gd").new()
	var racer = load("res://src/ai/brains/racer_armed_brain.gd").new()
	var siege = load("res://src/ai/brains/siege_brain.gd").new()
	scene.ctx.fighter(0).facing = Vector3.FORWARD
	scene.ctx.fighter(1).global_position = Vector3(0, 2, 1)
	scene.ctx.fighter(2).global_position = Vector3(0, 2, 2)
	scene.ctx.fighter(3).global_position = Vector3(10, 1, 0)
	for brain in [zone, bomber, climber, racer, siege]:
		brain.configure(0, scene.ctx, 3, 119)
		brain.reaction_time = 0.0
		brain.strategy = 1.0
		brain._record_history()
	scene.ctx.fighter(1).hide()
	t.equal(zone._rival_in_zone(Vector3(0, 2, 1), 3.0), 2, "zone bot chooses visible intruder instead of hidden rival")
	t.equal(climber._rival_above(), 2, "climber chooses visible rival above it")
	scene.ctx.fighter(2).hide()
	t.equal(zone._rival_in_zone(Vector3(0, 2, 1), 3.0), -1, "hidden rivals cannot occupy a zone for the bot")
	t.equal(climber._rival_above(), -1, "hidden rivals cannot lure the climber upward")
	t.ok(not bomber._rival_within(4.0), "hidden nearby rivals cannot make a bomb worth collecting")
	t.ok(not racer._tailed(), "hidden remembered follower cannot trigger a race mine")
	var race_controller := RaceCueProbe.new()
	racer.controller = race_controller
	t.ok(not racer._should_use(racer.Race.Item.MISSILE, scene.ctx.fighter(0)), "hidden race target cannot trigger a deliberate missile")
	scene.ctx.fighter(1).show()
	t.ok(bomber._rival_within(4.0), "visible nearby rival can justify collecting a bomb")
	t.ok(racer._tailed(), "visible follower still triggers a race mine")
	t.ok(racer._should_use(racer.Race.Item.MISSILE, scene.ctx.fighter(0)), "visible race target can trigger a deliberate missile")
	racer.controller = null
	race_controller.free()
	var base_controller = load("res://src/minigames/base_siege.gd").new()
	base_controller.ctx = scene.ctx
	siege.controller = base_controller
	var bases: Array[Node3D] = []
	for slot in 4:
		var base := Node3D.new()
		scene.add_child(base)
		base.global_position = Vector3(slot, 1, 0)
		bases.append(base)
		base_controller._bases.append({"slot": slot, "node": base, "health": [100, 1, 80, 0][slot]})
	scene.ctx.fighter(1).hide()
	scene.ctx.fighter(2).show()
	t.equal(siege._intruder_at_home(), 2, "siege bot ignores hidden home intruder")
	bases[1].hide()
	t.equal(siege._weakest_rival_base(), 2, "siege bot ignores hidden crystal despite low health")
	bases[2].hide()
	t.equal(siege._weakest_rival_base(), -1, "siege bot has no visible living crystal to attack")
	bases[1].show()
	t.equal(siege._weakest_rival_base(), 1, "visible crystal remains attackable while its owner is hidden")
	siege.controller = null
	base_controller.free()
	for base in bases: base.queue_free()
	var static_root: Node3D = scene.arena.get_node_or_null("Static")
	if static_root == null:
		static_root = Node3D.new()
		static_root.name = "Static"
		scene.arena.add_child(static_root)
	var hidden_ledge := Node3D.new()
	var visible_ledge := Node3D.new()
	static_root.add_child(hidden_ledge)
	static_root.add_child(visible_ledge)
	hidden_ledge.global_position = Vector3(0, 104, 0)
	visible_ledge.global_position = Vector3(1, 102, 0)
	hidden_ledge.hide()
	t.equal(climber._find_higher_ground(Vector3(0, 100, 0)), Vector3(1, 103, 0), "climber ignores hidden higher geometry")
	hidden_ledge.queue_free()
	visible_ledge.queue_free()


func _test_keeper_balls(t: TestHarness, scene: Node) -> void:
	var keeper = load("res://src/ai/brains/keeper_brain.gd").new()
	var magnet = load("res://src/ai/brains/magnet_keeper_brain.gd").new()
	var controller := MagnetCueProbe.new()
	for brain in [keeper, magnet]:
		brain.controller = controller
		brain.configure(0, scene.ctx, 3, 119)
		brain.strategy = 1.0
		brain._goal_pos = Vector3.ZERO
	scene.ctx.fighter(0).global_position = Vector3.ZERO
	var balls: Array[GameBall] = []
	for index in 3:
		var ball := GameBall.new()
		scene.add_child(ball)
		ball.add_to_group("balls")
		ball.global_position = Vector3(index + 1, 0, 0)
		ball.velocity = Vector3.LEFT
		balls.append(ball)
	balls[0].hide()
	balls[1].hide()
	t.equal(keeper._most_dangerous_ball(), balls[2], "keeper ignores closer hidden balls")
	magnet.decide(0.0)
	t.equal(magnet.bits & InputFrame.Btn.ABILITY, 0, "hidden balls cannot contribute to a multi-ball magnet trigger")
	balls[1].show()
	magnet.bits = 0
	magnet.decide(0.0)
	t.ok((magnet.bits & InputFrame.Btn.ABILITY) != 0, "two visible incoming balls still trigger the magnet")
	balls[1].queue_free()
	balls[2].queue_free()
	t.equal(keeper._most_dangerous_ball(), null, "keeper excludes queued balls")
	for ball in balls:
		ball.remove_from_group("balls")
		if not ball.is_queued_for_deletion(): ball.queue_free()
	keeper.controller = null
	magnet.controller = null
	controller.free()


func _test_bomb_states(t: TestHarness, scene: Node) -> void:
	var controller = load("res://src/minigames/fawda.gd").new()
	var bombs: Array[Node3D] = []
	for index in 3:
		var bomb := Node3D.new()
		scene.add_child(bomb)
		bomb.global_position = Vector3(index, 1, 0)
		bombs.append(bomb)
		controller._bombs.append({"node": bomb, "fuse": 5.0, "held": -1})
	bombs[0].hide()
	bombs[1].queue_free()
	var states: Array = controller.bomb_states()
	t.equal(states.size(), 1, "bomb perception API excludes hidden and queued ordnance")
	if states.size() == 1:
		t.equal(states[0]["pos"], bombs[2].global_position, "visible bomb position remains observable")
	controller.free()
	for bomb in bombs:
		if not bomb.is_queued_for_deletion(): bomb.queue_free()
