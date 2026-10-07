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
	var charge_ready := true
	func magnet_ready(_slot: int) -> bool:
		return charge_ready

class MagnetDeadlineProbe extends "res://src/ai/brains/magnet_keeper_brain.gd":
	var observations := {}
	func _most_dangerous_ball() -> GameBall:
		return null
	func perceive_ball(ball: GameBall) -> Dictionary:
		return observations.get(ball.get_instance_id(), {})

class RelicCueProbe extends MiniGameController:
	var item: Node3D
	var carrier := -1
	func holder() -> int:
		return carrier
	func loose_relic() -> Node3D:
		return item if carrier < 0 else null

class RelicSteeringProbe extends "res://src/ai/brains/relic_brain.gd":
	var destination := Vector3.ZERO
	func steer_to(target: Vector3, _urgency: float = 1.0) -> void:
		destination = target

class TagCueProbe extends MiniGameController:
	var hunter_slot := 1
	func hunter() -> int:
		return hunter_slot

class TagSteeringProbe extends "res://src/ai/brains/tag_brain.gd":
	var destination := Vector3.ZERO
	func steer_to(target: Vector3, _urgency: float = 1.0) -> void:
		destination = target

class PlatformAttackProbe extends "res://src/ai/brains/platform_brain.gd":
	var attack_requests := 0
	func maybe_attack(_target_slot: int, _range: float = 2.4) -> void:
		attack_requests += 1


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
		hidden.global_position = Vector3(index * 0.25, 1, 0)
		t.ok(brain.can_observe(hidden), "history wrap fixture stays inside the camera")
		brain._record_history()
	hidden.hide()
	hidden.global_position = Vector3(9999, 1, 0)
	brain._time += 0.05
	brain._record_history()
	brain._time += 0.05
	t.equal(brain.perceive(1), Vector3((AIBrain.HISTORY_CAP + 3) * 0.25, 1, 0), "wrapped history retains newest last-seen position")
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
	_test_duellist_delay(t, scene)
	_test_ball(t, scene)
	_test_courier(t, scene)
	_test_platform(t, scene)
	_test_remaining_rivals(t, scene)
	_test_keeper_balls(t, scene)
	_test_magnet_deadline(t, scene)
	_test_bomb_states(t, scene)
	_test_bomb_delay(t, scene)
	_test_ball_delay(t, scene)
	_test_relic(t, scene)
	_test_tag(t, scene)
	_test_tag_strategy(t, scene)
	_test_camera_bounds(t, scene)
	_test_tied_leaders(t, scene)
	_test_tied_nearest(t, scene)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _test_camera_bounds(t: TestHarness, scene: Node) -> void:
	var original: Camera3D = scene.ctx.observation_camera
	var camera := ArenaCamera.new()
	scene.add_child(camera)
	camera.set_process(false)
	camera.set_perspective(90.0, 0.1, 50.0)
	camera.global_position = Vector3(0, 1, 10)
	camera.look_at(Vector3(0, 1, 0), Vector3.UP)
	scene.ctx.observation_camera = camera
	var brain := AIBrain.new()
	brain.configure(1, scene.ctx, 3, 119)
	var marker := Node3D.new()
	scene.add_child(marker)
	marker.global_position = Vector3(0, 1, 0)
	t.ok(brain.can_observe(marker), "camera observes an in-frame target before a render update")
	marker.global_position = Vector3(100, 1, 0)
	t.ok(not brain.can_observe(marker), "visible-in-tree target outside the frame is not observed")
	marker.global_position = Vector3(0, 1, 20)
	t.ok(not brain.can_observe(marker), "target behind camera is not observed")
	marker.global_position = Vector3(0, 1, -100)
	t.ok(not brain.can_observe(marker), "target beyond far plane is not observed")
	marker.global_position = Vector3(0, 1, 9.99)
	t.ok(not brain.can_observe(marker), "target before near plane is not observed")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	scene.add_child(mesh)
	mesh.global_position = Vector3(10.0 / camera.get_camera_projection().x.x + 0.2, 1, 0)
	t.ok(not brain._point_in_view(mesh.global_position), "partial mesh fixture origin is outside the viewport")
	t.ok(brain.can_observe(mesh), "mesh corners preserve partial-frame visibility")
	mesh.layers = 2
	camera.cull_mask = 1
	t.ok(not brain.can_observe(mesh), "camera-hidden visual layer cannot be observed")
	var reference: Fighter = scene.ctx.fighter(0)
	var me: Fighter = scene.ctx.fighter(1)
	var reference_position := reference.global_position
	var my_position := me.global_position
	var reference_facing := reference.facing
	var my_facing := me.facing
	reference.global_position = Vector3(0, 1, 0)
	reference.facing = Vector3.FORWARD
	me.global_position = Vector3(100, 1, 100)
	me.facing = Vector3.RIGHT
	camera.local_target = reference
	camera.mode = ArenaCamera.Mode.CHASE
	marker.global_position = me.global_position + Vector3.RIGHT * 3
	t.ok(brain.can_observe(marker), "follow-camera bot observes from its own position and heading")
	marker.global_position = me.global_position + Vector3.LEFT * 100
	t.ok(not brain.can_observe(marker), "bot cannot use another player's camera to see behind its own view")
	camera.shared_world = true
	marker.global_position = me.global_position + Vector3.RIGHT * 3
	t.ok(not brain.can_observe(marker), "shared camera uses the shared frame rather than a private follow view")
	camera.set_orthogonal(20.0, 0.1, 50.0)
	marker.global_position = Vector3(0, 1, 0)
	t.ok(brain.can_observe(marker), "orthographic camera retains its in-frame target")
	marker.global_position = Vector3(30, 1, 0)
	t.ok(not brain.can_observe(marker), "orthographic camera excludes out-of-frame target")
	reference.global_position = reference_position
	me.global_position = my_position
	reference.facing = reference_facing
	me.facing = my_facing
	scene.ctx.observation_camera = original
	mesh.queue_free()
	marker.queue_free()
	camera.queue_free()


func _test_tied_nearest(t: TestHarness, scene: Node) -> void:
	t.test("equal nearby rivals do not always select the lowest player ID")
	scene.ctx.alive.fill(true)
	for fighter in scene.ctx.fighters:
		fighter.show()
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	scene.ctx.fighter(1).global_position = Vector3(3, 1, 0)
	scene.ctx.fighter(2).global_position = Vector3(-3, 1, 0)
	scene.ctx.fighter(3).global_position = Vector3(0, 1, 3)
	var brain := AIBrain.new()
	var replay_brain := AIBrain.new()
	brain.configure(0, scene.ctx, 3, 8341)
	replay_brain.configure(0, scene.ctx, 3, 8341)
	for observer in [brain, replay_brain]:
		observer._record_history()
		observer._time += observer.reaction_time
	var counts := [0, 0, 0, 0]
	for sample in 900:
		var selected := brain.nearest_rival()
		t.ok(selected in [1, 2, 3], "equal nearest candidates exclude self")
		t.equal(selected, replay_brain.nearest_rival(), "same seed reproduces nearest tie selection")
		if selected in [1, 2, 3]:
			counts[selected] += 1
	for rival in [1, 2, 3]:
		t.ok(counts[rival] >= 220 and counts[rival] <= 380, "nearest tie distributes across all equally close rivals")
	scene.ctx.fighter(3).global_position = Vector3(0, 1, 1)
	brain._record_history()
	brain._time += brain.reaction_time
	var state := brain.rng.state
	for sample in 30:
		t.equal(brain.nearest_rival(), 3, "unique closer rival takes priority over earlier equal candidates")
	t.equal(brain.rng.state, state, "unique nearest rival does not consume tie randomness")
	scene.ctx.fighter(3).hide()
	scene.ctx.alive[1] = false
	t.equal(brain.nearest_rival(), 2, "hidden and eliminated nearest rivals are excluded")
	scene.ctx.fighter(2).hide()
	t.equal(brain.nearest_rival(), -1, "no visible eligible nearest rival has no target")


func _test_tied_leaders(t: TestHarness, scene: Node) -> void:
	t.test("equal visible leaders do not always target the lowest player ID")
	scene.ctx.scores.fill(0)
	scene.ctx.alive.fill(true)
	for fighter in scene.ctx.fighters:
		fighter.show()
	var brain := AIBrain.new()
	var replay_brain := AIBrain.new()
	brain.configure(0, scene.ctx, 3, 5319)
	replay_brain.configure(0, scene.ctx, 3, 5319)
	for observer in [brain, replay_brain]:
		observer._record_history()
		observer._time += observer.reaction_time
	var counts := [0, 0, 0, 0]
	for sample in 900:
		var selected := brain.leader_rival()
		t.ok(selected in [1, 2, 3], "tied leader selection excludes self")
		t.equal(selected, replay_brain.leader_rival(), "same seed reproduces tied target choices")
		if selected in [1, 2, 3]:
			counts[selected] += 1
	for rival in [1, 2, 3]:
		t.ok(counts[rival] >= 220 and counts[rival] <= 380, "seeded tie fixture distributes targets across every eligible rival")
	scene.ctx.scores[3] = 10
	var rng_state := brain.rng.state
	for sample in 30:
		t.equal(brain.leader_rival(), 3, "unique visible highest score still takes priority")
	t.equal(brain.rng.state, rng_state, "unique leader does not consume tie randomness")
	scene.ctx.fighter(3).hide()
	scene.ctx.alive[1] = false
	for sample in 30:
		t.equal(brain.leader_rival(), 2, "hidden leader and eliminated rival are excluded before tie selection")
	scene.ctx.scores[2] = -9223372036854775807
	var minimum_rng := brain.rng.state
	t.equal(brain.leader_rival(), 2, "eligible negative score below old sentinel remains a target")
	t.equal(brain.rng.state, minimum_rng, "unique negative leader consumes no tie randomness")
	scene.ctx.fighter(2).hide()
	t.equal(brain.leader_rival(), -1, "no eligible visible rival has no target")


func _test_relic(t: TestHarness, scene: Node) -> void:
	var brain := RelicSteeringProbe.new()
	var cue := RelicCueProbe.new()
	scene.add_child(cue)
	brain.configure(0, scene.ctx, 3, 119)
	brain.controller = cue
	brain.reaction_time = 0.0
	var parent := Node3D.new()
	scene.ctx.world_root.add_child(parent)
	var item := Node3D.new()
	parent.add_child(item)
	cue.item = item
	t.equal(brain._loose_relic(), item, "relic bot can target a visible loose prize")
	item.hide()
	t.equal(brain._loose_relic(), null, "relic bot cannot locate a hidden loose prize")
	item.show()
	parent.hide()
	t.equal(brain._loose_relic(), null, "relic bot respects inherited prize visibility")
	parent.show()
	t.equal(brain._loose_relic(), item, "relic bot recovers when the prize reappears")
	cue.carrier = 1
	t.equal(brain._loose_relic(), null, "carried relic cannot remain a loose target")
	var carrier: Fighter = scene.ctx.fighter(1)
	carrier.global_position = Vector3(6, 1, 0)
	carrier.hide()
	brain.decide(0.0)
	t.equal(brain.destination, scene.arena.retreat_point(scene.ctx.fighter(0).global_position), "hidden holder does not reveal a pursuit destination")
	carrier.show()
	brain._record_history()
	brain.decide(0.0)
	t.ok(brain.destination.x > 0.0, "visible holder becomes a pursuit target again")
	cue.carrier = -1
	item.queue_free()
	t.equal(brain._loose_relic(), null, "queued relic cannot become a target")
	parent.queue_free()
	cue.queue_free()


func _test_tag(t: TestHarness, scene: Node) -> void:
	var saved_scores: Array[int] = scene.ctx.scores.duplicate()
	scene.ctx.scores.fill(0)
	var brain := TagSteeringProbe.new()
	var cue := TagCueProbe.new()
	scene.add_child(cue)
	brain.configure(0, scene.ctx, 3, 119)
	brain.controller = cue
	brain.reaction_time = 0.0
	brain.edge_awareness = 0.0
	var me: Fighter = scene.ctx.fighter(0)
	var hunter: Fighter = scene.ctx.fighter(1)
	me.global_position = Vector3(0, 1, 1)
	hunter.global_position = Vector3(6, 1, 1)
	hunter.hide()
	brain.on_round_start()
	brain.decide(0.0)
	var retreat: Vector3 = scene.arena.retreat_point(me.global_position)
	t.equal(brain.destination, retreat, "unseen hunter cannot create a phantom threat at the origin")
	hunter.global_position = Vector3(-30, 1, 20)
	brain.decide(0.0)
	t.equal(brain.destination, retreat, "unseen hunter movement cannot alter the runner destination")
	hunter.show()
	hunter.global_position = Vector3(6, 1, 1)
	brain._record_history()
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "runner flees a visible hunter")
	hunter.hide()
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "runner retains legitimate last-seen hunter memory")
	hunter.global_position = Vector3(-30, 1, 20)
	brain._time = 0.1
	brain._record_history()
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "hidden movement cannot change remembered threat direction")
	cue.hunter_slot = -1
	brain.decide(0.0)
	t.equal(brain.destination, retreat, "absent hunter retains safe retreat behavior")
	cue.hunter_slot = 0
	for slot in [2, 3]:
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot * 3, 1, 1)
	brain._time += 0.1
	brain._record_history()
	brain._time += 0.01
	brain.decide(0.0)
	t.ok(brain.destination.x > 0.0, "hunter pursues visible prey rather than a hidden rival")
	brain.on_round_start()
	t.ok(not brain.has_observed(1), "new round clears remembered hunter knowledge")
	hunter.show()
	hunter.global_position = Vector3.ZERO
	brain.reaction_time = 0.2
	brain._record_history()
	t.ok(not brain.has_observed(1), "first hunter observation waits for reaction delay")
	brain._time += 0.3
	t.ok(brain.has_observed(1), "actual origin position is a valid delayed observation")
	t.ok(not brain.has_observed(-1) and not brain.has_observed(4), "invalid hunter slots cannot be observed")
	scene.ctx.scores = saved_scores
	cue.queue_free()


func _test_tag_strategy(t: TestHarness, scene: Node) -> void:
	var saved_scores: Array[int] = scene.ctx.scores.duplicate()
	var saved_time: float = scene.ctx.time_left
	var brain := TagSteeringProbe.new()
	var cue := TagCueProbe.new()
	scene.add_child(cue)
	brain.configure(0, scene.ctx, 3, 119)
	brain.controller = cue
	brain.reaction_time = 0.0
	brain.edge_awareness = 0.0
	var me: Fighter = scene.ctx.fighter(0)
	var hunter: Fighter = scene.ctx.fighter(1)
	me.global_position = Vector3(0, 1, 0)
	hunter.global_position = Vector3(5, 1, 0)
	hunter.show()
	scene.ctx.scores.fill(0)
	scene.ctx.scores[2] = 6
	scene.ctx.time_left = 30.0
	brain._record_history()
	brain.decide(0.0)
	t.equal(brain.destination, Vector3(5, 1, 0), "trailing expert can challenge observed hunter to earn the next tag")
	brain.strategy = 0.2
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "low-strategy runner retains simple escape behavior")
	brain.strategy = 0.95
	scene.ctx.scores[0] = 7
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "leading expert protects free-time points rather than farming roles")
	scene.ctx.scores[0] = 0
	scene.ctx.time_left = 1.0
	brain.decide(0.0)
	t.ok(brain.destination.x < 0.0, "insufficient remaining time prevents futile role challenge")
	scene.ctx.time_left = 30.0
	hunter.hide()
	hunter.global_position = Vector3(-20, 1, 0)
	brain._record_history()
	brain.decide(0.0)
	t.equal(brain.destination, Vector3(5, 1, 0), "catch-up strategy uses remembered cue not hidden hunter movement")
	brain.on_round_start()
	brain.decide(0.0)
	t.equal(brain.destination, scene.arena.retreat_point(me.global_position), "scores cannot disclose never-observed hunter location")
	scene.ctx.scores = saved_scores
	scene.ctx.time_left = saved_time
	cue.queue_free()


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
		scene.ctx.fighter(slot).mods["shield"] = 0.0
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
	for fighter in scene.ctx.fighters:
		t.ok(fighter.mods.has("frozen"), "duo fixture preserves the effect schema used by the live HUD")


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
	duellist._record_history()
	t.equal(duellist._best_target(), 2, "duellist targets visible damaged rival rather than hidden leader")
	scene.ctx.fighter(2).hide()
	t.equal(duellist._best_target(), 3, "duellist retains remaining visible target")
	scene.ctx.fighter(3).hide()
	t.equal(duellist._best_target(), -1, "duellist has no target when rivals are hidden")
	scene.ctx.fighter(1).show()
	duellist._record_history()
	t.equal(duellist._best_target(), 1, "duellist can target damaged rival after it reappears")


func _test_duellist_delay(t: TestHarness, scene: Node) -> void:
	var duellist = load("res://src/ai/brains/duellist_brain.gd").new()
	duellist.configure(0, scene.ctx, 3, 119)
	duellist.reaction_time = 0.5
	duellist.strategy = 1.0
	scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
	for slot in range(1, 4):
		scene.ctx.fighter(slot).show()
		scene.ctx.fighter(slot).global_position = Vector3(slot + 1, 1, 0)
		scene.ctx.fighter(slot).damage_percent = 0.0
	scene.ctx.fighter(1).damage_percent = 90.9
	duellist._record_history()
	duellist._time = 0.3
	scene.ctx.fighter(2).damage_percent = 140.0
	duellist._record_history()
	duellist._time = 0.6
	t.near(duellist.perceived_damage(1), 90.0, 0.001, "damage perception uses the displayed integer percentage")
	t.equal(duellist._best_target(), 1, "damage target selection waits for the same reaction delay as movement")
	duellist._time = 0.8
	t.equal(duellist._best_target(), 2, "observed damage becomes actionable after its reaction delay")
	scene.ctx.fighter(1).damage_percent = 999.0
	t.equal(duellist._best_target(), 2, "unsampled future damage cannot override the delayed target")
	scene.ctx.fighter(2).hide()
	t.equal(duellist._best_target(), 1, "hidden damaged rival cannot remain an actionable target")
	t.near(duellist.perceived_damage(2), 0.0, 0.001, "hidden damage is not an actionable observation")
	t.near(duellist.perceived_damage(-1), 0.0, 0.001, "invalid negative damage slot is unknown")
	t.near(duellist.perceived_damage(4), 0.0, 0.001, "out-of-range damage slot is unknown")
	scene.ctx.fighter(2).show()
	duellist.reaction_time = 0.0
	for sample in AIBrain.HISTORY_CAP + 5:
		duellist._time += 0.05
		scene.ctx.fighter(2).damage_percent = 20.9 + sample
		duellist._record_history()
	t.equal(duellist._history_damage.size(), AIBrain.HISTORY_CAP, "damage observation storage stays bounded")
	t.near(duellist.perceived_damage(2), 20.0 + AIBrain.HISTORY_CAP + 4, 0.001, "wrapped history retains the latest observed damage")
	duellist.on_round_start()
	t.equal(duellist._history_damage.size(), 0, "new round clears retained damage observations")
	t.equal(duellist._best_target(), -1, "new round cannot use old damage or a live unsampled fallback")


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
		else: scene.ctx.world_root.add_child(ball)
		ball.add_to_group("balls")
		balls.append(ball)
	balls[0].hide()
	brain._record_history()
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
	for index in 4:
		scene.ctx.fighter(index).show()
	scene.ctx.fighter(1).global_position = Vector3(5, 1, 0)
	scene.ctx.fighter(2).global_position = Vector3(-5, 1, 0)
	scene.ctx.fighter(3).global_position = Vector3(0, 1, 5)
	brain._record_history()
	brain.rng.seed = 211
	var counts := [0, 0, 0, 0]
	for attempt in 900:
		counts[brain._best_victim(Vector3(0, 1, 0))] += 1
	for index in [1, 2, 3]:
		t.ok(counts[index] > 200 and counts[index] < 400, "equal-distance blast victims are not selected by seat order")
	brain.rng.seed = 212
	var sequence := []
	for attempt in 30:
		sequence.append(brain._best_victim(Vector3(0, 1, 0)))
	brain.rng.seed = 212
	for attempt in 30:
		t.equal(brain._best_victim(Vector3(0, 1, 0)), sequence[attempt], "victim ties reproduce from the match seed")
	scene.ctx.fighter(3).global_position = Vector3(0, 1, 1)
	brain._record_history()
	var rng_state: int = brain.rng.state
	t.equal(brain._best_victim(Vector3(0, 1, 0)), 3, "unique nearest victim wins even after earlier equal candidates")
	t.equal(brain.rng.state, rng_state, "unique victim selection does not consume random state")
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
	var origin := ArenaTile.new()
	scene.add_child(origin)
	origin.global_position = scene.ctx.fighter(0).global_position
	origin.state = ArenaTile.State.WARNING
	tile.grid_z = 1
	tile.global_position = origin.global_position + Vector3(0, 0, 2)
	other.grid_x = 1
	other.global_position = origin.global_position + Vector3(2, 0, 0)
	var tiles: Array[ArenaTile] = scene.arena.tiles.duplicate()
	scene.arena.tiles.clear()
	scene.arena.tiles.append(tile)
	scene.arena.tiles.append(other)
	scene.arena.tiles.append(origin)
	tile.hide()
	t.equal(brain._pick_tile(scene.arena, origin.global_position), other, "hidden solid floor cannot become a platform target")
	t.equal(brain._solid_neighbours(scene.arena, other), 0.0, "hidden floor cannot improve a tile's neighbour score")
	other.hide()
	t.equal(brain._pick_tile(scene.arena, origin.global_position), null, "platform bot has no destination when all solid tiles are hidden")
	brain._target_tile = tile
	brain.decide(0.0)
	t.equal(brain._target_tile, null, "platform bot discards a cached tile once it becomes hidden")
	other.show()
	brain.decide(0.0)
	t.equal(brain._target_tile, other, "platform bot resumes targeting visible solid ground")
	var attacker := PlatformAttackProbe.new()
	attacker.configure(0, scene.ctx, 3, 119)
	attacker.reaction_time = 0.0
	attacker.aggression = 0.0
	scene.ctx.fighter(1).global_position = tile.global_position
	tile.state = ArenaTile.State.WARNING
	attacker._record_history()
	attacker.decide(0.0)
	t.equal(attacker.attack_requests, 0, "hidden rival floor warning cannot trigger an opportunistic shove")
	tile.show()
	attacker.decide(0.0)
	t.equal(attacker.attack_requests, 1, "visible rival floor warning still permits a shove")
	tile.hide()
	attacker.decide(0.0)
	t.equal(attacker.attack_requests, 1, "hiding the floor removes warning-based attack credit")
	for difficulty in 4:
		var delayed := PlatformAttackProbe.new()
		delayed.configure(0, scene.ctx, difficulty, 119)
		delayed.aggression = 0.0
		delayed._record_history()
		delayed._time = 10.0
		tile.show()
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 0, "tier %d newly seen rival floor warning waits for reaction" % difficulty)
		delayed._time = 10.0 + delayed.reaction_time - 0.001
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 0, "tier %d warning remains delayed before threshold" % difficulty)
		delayed._time = 10.0 + delayed.reaction_time
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 1, "tier %d warning becomes actionable at threshold" % difficulty)
		tile.hide()
		delayed.decide(0.0)
		tile.show()
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 1, "tier %d reappearing warning must earn fresh reaction credit" % difficulty)
		delayed._time += delayed.reaction_time
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 2, "tier %d reappearing warning becomes actionable after delay" % difficulty)
		tile.state = ArenaTile.State.SOLID
		delayed.decide(0.0)
		tile.state = ArenaTile.State.WARNING
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 2, "tier %d restored floor cannot retain warning credit" % difficulty)
		delayed._time += delayed.reaction_time
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 3, "tier %d new floor warning becomes actionable after delay" % difficulty)
		delayed.on_round_start()
		delayed._record_history()
		delayed._time += delayed.reaction_time + 1.0
		delayed.decide(0.0)
		t.equal(delayed.attack_requests, 3, "tier %d new round discards floor warning observations" % difficulty)
	scene.arena.tiles = tiles
	tile.queue_free()
	other.queue_free()
	origin.queue_free()


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
	var view: Transform3D = scene.camera.global_transform
	scene.camera.global_position += Vector3.UP * 100.0
	t.equal(climber._find_higher_ground(Vector3(0, 100, 0)), Vector3(1, 103, 0), "climber ignores hidden higher geometry")
	scene.camera.global_transform = view
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
		brain.reaction_time = 0.0
		brain._goal_pos = Vector3.ZERO
	scene.ctx.fighter(0).global_position = Vector3.ZERO
	var balls: Array[GameBall] = []
	for index in 3:
		var ball := GameBall.new()
		scene.ctx.world_root.add_child(ball)
		ball.add_to_group("balls")
		ball.global_position = Vector3(index + 1, 0, 0)
		ball.velocity = Vector3.LEFT
		balls.append(ball)
	balls[0].hide()
	balls[1].hide()
	for brain in [keeper, magnet]: brain._record_history()
	for ball in balls: ball.global_position += Vector3.LEFT * 0.1
	for brain in [keeper, magnet]:
		brain._time = 0.1
		brain._record_history()
	t.equal(keeper._most_dangerous_ball(), balls[2], "keeper ignores closer hidden balls")
	magnet.decide(0.0)
	t.equal(magnet.bits & InputFrame.Btn.ABILITY, 0, "hidden balls cannot contribute to a multi-ball magnet trigger")
	balls[1].show()
	for brain in [keeper, magnet]:
		brain._time = 0.2
		brain._record_history()
	for ball in balls: ball.global_position += Vector3.LEFT * 0.1
	for brain in [keeper, magnet]:
		brain._time = 0.3
		brain._record_history()
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


func _test_magnet_deadline(t: TestHarness, scene: Node) -> void:
	var controller := MagnetCueProbe.new()
	var brain := MagnetDeadlineProbe.new()
	brain.controller = controller
	brain.configure(0, scene.ctx, 3, 119)
	brain.strategy = 1.0
	scene.ctx.fighter(0).global_position = Vector3.ZERO
	var ball := GameBall.new()
	scene.ctx.world_root.add_child(ball)
	ball.add_to_group("balls")
	ball.global_position = Vector3(3, 0, 0)
	ball.velocity = Vector3.RIGHT * 999.0
	for normal in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var observed_position: Vector3 = -normal * 3.0
		brain.observations[ball.get_instance_id()] = {"position": observed_position, "velocity": normal * 10.0}
		brain.bits = 0
		brain.decide(0.0)
		t.ok((brain.bits & InputFrame.Btn.ABILITY) != 0, "expert saves an urgent single ball from observed motion")
		brain.observations[ball.get_instance_id()]["velocity"] = normal
		brain.bits = 0
		brain.decide(0.0)
		t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "expert preserves the charge for a distant slow arrival")
		brain.observations[ball.get_instance_id()]["velocity"] = -normal * 10.0
		brain.bits = 0
		brain.decide(0.0)
		t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "departing single ball cannot trigger emergency magnet")
	brain.observations[ball.get_instance_id()] = {"position": Vector3(3, 0, 3), "velocity": Vector3.LEFT * 10.0}
	brain.bits = 0
	brain.decide(0.0)
	t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "fast passing ball outside catch radius preserves the charge")
	brain.observations[ball.get_instance_id()] = {"position": Vector3(3, 0, 0), "velocity": Vector3.LEFT * 10.0}
	ball.hide()
	brain.bits = 0
	brain.decide(0.0)
	t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "hidden urgent ball cannot trigger emergency magnet")
	ball.show()
	controller.charge_ready = false
	brain.bits = 0
	brain.decide(0.0)
	t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "empty visible charge prevents emergency activation")
	controller.charge_ready = true
	brain.observations.clear()
	brain.bits = 0
	brain.decide(0.0)
	t.equal(brain.bits & InputFrame.Btn.ABILITY, 0, "not yet perceived urgent ball cannot trigger emergency magnet")
	ball.remove_from_group("balls")
	ball.queue_free()
	brain.controller = null
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


func _test_bomb_delay(t: TestHarness, scene: Node) -> void:
	var controller = load("res://src/minigames/fawda.gd").new()
	var visual: Dictionary = controller.make_bomb_visual()
	var bomb: Node3D = visual.node
	scene.add_child(bomb)
	bomb.global_position = Vector3(2, 1, 0)
	controller.update_bomb_visual(visual, 4.1)
	controller._bombs.append({"node": bomb, "wick": visual.wick, "fuse": 0.01, "held": -1})
	var brain = load("res://src/ai/brains/bomber_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 119)
	brain.controller = controller
	brain.reaction_time = 0.2
	var cues: Array = controller.bomb_states()
	t.equal(cues[0].fuse, 4.0, "bomb cue estimates rendered wick rather than secret fuse")
	t.equal(brain._observed_bombs().size(), 0, "unobserved bomb gives no live fallback")
	brain._record_history()
	t.equal(brain._observed_bombs().size(), 0, "new bomb waits for reaction delay")
	brain._time = 0.1
	bomb.global_position = Vector3(9, 1, 0)
	controller.update_bomb_visual(visual, 1.0)
	brain._record_history()
	brain._time = 0.2
	var observed: Array = brain._observed_bombs()
	t.equal(observed.size(), 1, "mature bomb observation becomes available")
	if not observed.is_empty():
		t.equal(observed[0].pos, Vector3(2, 1, 0), "bomb pursuit uses delayed position")
		t.equal(observed[0].fuse, 4.0, "bomb urgency uses delayed visible wick")
	brain._time = 0.3
	observed = brain._observed_bombs()
	t.equal(observed[0].fuse, 1.0, "later wick cue respects same reaction delay")
	bomb.global_position = Vector3(999, 1, 0)
	t.equal(brain._observed_bombs().size(), 0, "out-of-frame bomb cannot remain actionable through history")
	brain._record_history()
	t.equal(brain._bomb_history.back().bombs.size(), 0, "out-of-frame bomb cannot enter observation history")
	bomb.global_position = Vector3(9, 1, 0)
	bomb.hide()
	t.equal(brain._observed_bombs().size(), 0, "hidden bomb cannot remain actionable through history")
	bomb.show()
	visual.wick.hide()
	t.equal(controller.bomb_states()[0].fuse, -1.0, "hidden wick does not expose private countdown")
	for index in AIBrain.HISTORY_CAP + 5:
		brain._time += 0.05
		brain._record_history()
	t.equal(brain._bomb_history.size(), AIBrain.HISTORY_CAP, "bomb observation memory remains bounded")
	brain.on_round_start()
	t.equal(brain._observed_bombs().size(), 0, "round restart clears bomb observations")
	bomb.queue_free()
	t.equal(controller.bomb_states().size(), 0, "queued bomb cannot be observed")
	brain.controller = null
	controller.free()


func _test_ball_delay(t: TestHarness, scene: Node) -> void:
	var keeper = load("res://src/ai/brains/keeper_brain.gd").new()
	var controller := MagnetCueProbe.new()
	keeper.controller = controller
	keeper.configure(0, scene.ctx, 3, 119)
	keeper._goal_pos = Vector3.ZERO
	keeper.reaction_time = 0.2
	var balls: Array[GameBall] = []
	for index in 2:
		var ball := GameBall.new()
		scene.ctx.world_root.add_child(ball)
		ball.add_to_group("balls")
		ball.global_position = Vector3(2 if index == 0 else 6, 0, 0)
		ball.velocity = Vector3.RIGHT if index == 0 else Vector3.LEFT
		balls.append(ball)
	t.equal(keeper._most_dangerous_ball(), null, "keeper cannot react to a ball it has not observed")
	keeper._time = 0.0
	keeper._record_history()
	t.equal(keeper._most_dangerous_ball(), null, "new ball observation waits for reaction delay")
	keeper._time = 0.2
	balls[0].global_position = Vector3(20, 0, 0)
	balls[1].global_position = Vector3(4, 0, 0)
	keeper._record_history()
	keeper._time = 0.3
	t.equal(keeper._most_dangerous_ball(), balls[0], "keeper threat ranking uses delayed observed position rather than live velocity")
	keeper._time = 0.5
	t.equal(keeper._most_dangerous_ball(), balls[1], "keeper updates threat ranking after the observation delay")
	balls[1].velocity = Vector3(999, 0, 0)
	var observation: Dictionary = keeper.perceive_ball(balls[1])
	t.equal(observation.get("velocity"), Vector3(-10, 0, 0), "ball prediction infers motion instead of reading private velocity")
	observation["position"] = Vector3(999, 0, 0)
	t.equal(keeper.perceive_ball(balls[1]).get("position"), Vector3(4, 0, 0), "returned observation cannot mutate retained history")
	balls[1].configure(Color.WHITE, 0.5, false, true)
	balls[1]._label.text = "4.0"
	balls[1].fuse = 999.0
	keeper._time = 0.6
	keeper._record_history()
	balls[1].radius = 999.0
	t.near(balls[1].visible_radius(), 0.5, 0.0001, "rendered sphere size does not expose private physics radius")
	balls[1]._label.text = "1.0"
	keeper._time = 0.7
	keeper._record_history()
	balls[1].configure(Color.WHITE, 0.9, false, true)
	keeper._time = 0.8
	t.equal(keeper.perceive_ball(balls[1]).get("fuse"), 4.0, "ball fuse comes from the delayed displayed label, not its private timer")
	t.near(float(keeper.perceive_ball(balls[1]).get("radius", -1.0)), 0.5, 0.0001, "ball size uses delayed rendered geometry, not private or future radius")
	balls[1]._label.hide()
	keeper._time = 0.9
	keeper._record_history()
	keeper._time = 1.2
	t.equal(keeper.perceive_ball(balls[1]).get("fuse"), -1.0, "hidden fuse label does not reveal a timer")
	t.near(float(keeper.perceive_ball(balls[1]).get("radius", -1.0)), 0.9, 0.0001, "changed visible sphere size becomes available after reaction delay")
	balls[1]._mesh.hide()
	keeper._time = 1.21
	keeper._record_history()
	keeper._time = 1.5
	t.ok(keeper.perceive_ball(balls[1]).is_empty(), "hidden sphere and fuse label expose no actionable ball observation")
	balls[1]._mesh.show()
	balls[1].hide()
	t.ok(keeper.perceive_ball(balls[1]).is_empty(), "hidden ball cannot return an actionable old observation")
	balls[1].show()
	balls[1].launch(Vector3(8, 1, 0), Vector3.FORWARD, 9.0)
	t.ok(keeper.perceive_ball(balls[1]).is_empty(), "relaunch cannot reuse the preceding trajectory")
	keeper._time = 1.6
	keeper._record_history()
	keeper._time = 1.7
	t.ok(keeper.perceive_ball(balls[1]).is_empty(), "relaunch also waits for reaction delay")
	keeper._time = 1.9
	t.equal(keeper.perceive_ball(balls[1]).get("velocity"), Vector3.ZERO, "relaunch does not infer velocity from teleport distance")
	keeper.on_round_start()
	t.equal(keeper._history_balls.size(), 0, "round restart discards ball observations")
	for index in AIBrain.HISTORY_CAP + 4:
		keeper._time = float(index) * 0.05
		keeper._record_history()
	t.equal(keeper._history_balls.size(), AIBrain.HISTORY_CAP, "ball observation history stays bounded after ring wrap")
	var non_ball_brain := AIBrain.new()
	non_ball_brain.configure(0, scene.ctx, 3, 119)
	non_ball_brain._record_history()
	t.ok(non_ball_brain._history_balls[0].is_empty(), "non-ball brains do not collect ball state")
	var foreign := GameBall.new()
	scene.add_child(foreign)
	foreign.add_to_group("balls")
	keeper._time += 0.1
	keeper._record_history()
	t.ok(keeper.perceive_ball(foreign).is_empty(), "ball outside this match cannot be observed")
	foreign.remove_from_group("balls")
	foreign.queue_free()
	for ball in balls:
		ball.remove_from_group("balls")
		ball.queue_free()
	keeper.controller = null
	controller.free()
