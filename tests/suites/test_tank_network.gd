extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")

class AmmoSteeringProbe extends "res://src/ai/brains/tank_brain.gd":
	var destination := Vector3.ZERO
	var blocked := Vector3(INF, INF, INF)
	func drive_to(target: Vector3, _reverse_when_stuck: bool = true) -> void:
		destination = target
	func _has_line_of_sight(_from: Vector3, to: Vector3) -> bool:
		return not to.is_equal_approx(blocked)


class RouteSteeringProbe extends AmmoSteeringProbe:
	var next_target := Vector3(12, 0, 12)
	func priority_rival() -> int:
		return 1
	func predict(_target_slot: int, _lead: float = 0.35) -> Vector3:
		return next_target
	func _has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return false
	func _visible_weapon_crate() -> Node3D:
		return null


class RoutingWorld extends RefCounted:
	var calls := 0
	var waypoint := Vector3(6, 1, 0)
	func route(from: Vector3, _to: Vector3) -> PackedVector3Array:
		calls += 1
		return PackedVector3Array([from, waypoint])


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var cfg := MatchConfig.build("tank_arena", ["fanoos", "mowja", "ramla", "nabta"], 1, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	_test_routing_clock(t, scene)
	_test_ammo_perception(t, scene)
	var peer: Node = load("res://tests/network_peer.gd").new()
	peer.game = scene
	var origin: Vector3 = game.world.roads.get_point_position(0)
	var destination: Vector3 = game.world.roads.get_point_position(24)
	var waypoint: Vector3 = peer._tank_waypoint(origin, destination)
	t.ok(waypoint.distance_to(origin) > 3.0, "ATV fixture advances beyond its starting road node")
	var between := origin.lerp(waypoint, 0.35)
	var recalculated: PackedVector3Array = game.world.route(between, destination)
	t.equal(recalculated[0], origin, "per-frame nearest-node routing reproduces the backward waypoint")
	t.equal(peer._tank_waypoint(between, destination), waypoint, "ATV route does not steer back when nearest-node lookup still selects origin")
	t.ok(peer._tank_waypoint(waypoint, destination).distance_to(waypoint) > 3.0, "ATV fixture advances after reaching each waypoint")
	peer.free()
	await _test_peer_corridor(t, host, scene)
	t.not_null(game._engine, "audio-enabled test creates an actual engine player")
	for kind in 7:
		game._spawn_shell(0, kind, Vector3(100, 4, 100), Vector3.FORWARD)
		t.equal(game._shots.back().shell_kind, kind, "real shell keeps its presentation kind")
	var guided: Projectile = game._shots[3]
	guided.direction = Vector3(0, 0.6, 0.8)
	game._shots[6]._sticky_left = 0.5
	game.armor[1] = 75
	game.ammo[1] = 6
	game.shell_types[1] = 1
	game.crates[0].cooldown = 8.0
	game.crates[1].node.rotation.y = 20.0
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "tank_arena"), "all seven real shell types accepted after JSON serialization")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "tank_arena"), "missing world field rejected")
	for field in ["armor", "ammo", "shell_types"]:
		for value in [-1, 101, INF, NAN, "1", true, 1.5]:
			var bad := packet.duplicate(true)
			bad.world[field][0] = value
			t.ok(not replica.accept(bad, 4, "tank_arena"), "invalid inventory value rejected")
		var bad := packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "tank_arena"), "wrong roster rejected")
	for pair in [[1, 0], [0, 1], [4, 2], [7, 1]]:
		var bad := packet.duplicate(true)
		bad.world.ammo[0] = pair[0]
		bad.world.shell_types[0] = pair[1]
		t.ok(not replica.accept(bad, 4, "tank_arena"), "inconsistent ammunition rejected")
	for change in [{"kind": 7}, {"kind": "1"}, {"kind": true}, {"kind": 1.5}, {"fuse": -0.5}, {"fuse": 2.01},
		{"fuse": INF}, {"fuse": NAN}, {"fuse": "1"}, {"kind": 0, "fuse": 0}, {"generation": 0},
		{"id": "01"}, {"direction": [0, 0, 0]}, {"shooter": 4}, {"extra": 1}]:
		var bad := packet.duplicate(true)
		bad.world.shots[0].merge(change, true)
		t.ok(not replica.accept(bad, 4, "tank_arena"), "invalid shell rejected")
	for change in [{"cooldown": -1}, {"cooldown": 9.01}, {"cooldown": "0"}, {"rotation": PI + 0.001}, {"rotation": NAN}, {"extra": 1}]:
		var bad := packet.duplicate(true)
		bad.world.crates[0].merge(change, true)
		t.ok(not replica.accept(bad, 4, "tank_arena"), "invalid crate rejected")
	for field in ["shots", "crates"]:
		var bad := packet.duplicate(true)
		bad.world[field].append(bad.world[field][0].duplicate(true))
		t.ok(not replica.accept(bad, 4, "tank_arena"), "duplicate shot or wrong crate count rejected")
	t.equal(replica.target, packet, "invalid data never replaces accepted state")
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	var voice: int = AudioManager._next_voice
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "baseline cannot replay prior cannon launches")
	t.ok(game._shots.is_empty(), "guest has no independently simulated projectiles")
	t.equal(Pool.stats()[game.POOL_KEY].live, 0, "guest returns all shots to pool")
	t.equal(replica._tank.shots.size(), 7, "seven shell visuals retained")
	t.ok(not _has_collision(replica._tank), "visual projectiles cannot damage or collide")
	t.equal(game.armor[1], 75, "host armor restored")
	t.equal(game.ammo[1], 6, "host ammo restored")
	t.equal(game.shell_types[1], 1, "host weapon restored")
	t.ok(not game.crates[0].node.visible, "collected crate stays hidden")
	t.ok(game.crates[1].node.visible, "ready crate visible")
	t.near(game.crates[1].node.rotation.y, wrapf(20.0, -PI, PI), 0.001, "host crate rotation wraps and restores")
	var scores: Array = Array(scene.ctx.scores).duplicate()
	for repeat in 10:
		replica.render(scene, 0.016)
	t.equal(game.ammo[1], 6, "presentation does not spend ammunition")
	t.near(game.crates[0].cooldown, 8.0, 0.001, "presentation does not respawn crates")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot award eliminations")
	for row in packet.world.shots:
		var key: String = row.id + ":" + str(int(row.generation))
		var view: Node3D = replica._tank.shots[key]
		t.equal(view.get_meta("kind"), int(row.kind), "host shell kind restored")
		t.near(view.get_meta("fuse"), float(row.fuse), 0.001, "host fuse copied without ticking")
		t.ok(view.global_position.is_equal_approx(Vector3(row.position[0], row.position[1], row.position[2])), "host shot position restored")
		var core: MeshInstance3D = view.get_child(0)
		t.ok(core.material_override.albedo_color.is_equal_approx(game.SHELL_COLORS[int(row.kind)]), "shell uses its real weapon color")
	packet.world.shots[3].direction = [0, 1, 0]
	t.ok(replica.accept(packet, 4, "tank_arena"), "vertical guided trajectory accepted")
	replica.render(scene, 0.016)
	var guided_key: String = packet.world.shots[3].id + ":" + str(int(packet.world.shots[3].generation))
	t.ok((-replica._tank.shots[guided_key].global_basis.z).is_equal_approx(Vector3.UP), "vertical trajectory has a valid visual orientation")
	t.ok(game._engine.playing, "engine runs during active guest play")
	packet.phase = MatchPhase.P.RESULTS
	t.ok(replica.accept(packet, 4, "tank_arena"), "results state accepted")
	replica.render(scene, 0.016)
	t.ok(not game._engine.playing, "engine stops in results instead of restarting")
	game._spawn_shell(0, 2, Vector3(100, 4, 100), Vector3.FORWARD)
	packet = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	game.cleanup()
	packet.phase = MatchPhase.P.PLAYING
	AudioManager._last_played.erase("cannon_fire")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "tank_arena"), "new heavy shell accepted")
	# Isolate the cannon from the HUD's separate go cue on results -> playing.
	replica._last_phase = MatchPhase.P.PLAYING
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh heavy shell plays cannon audio once")
	voice = AudioManager._next_voice
	AudioManager._last_played.erase("cannon_fire")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate launch stays silent without debounce")
	packet.world.shots[0].generation += 1
	t.ok(replica.accept(packet, 4, "tank_arena"), "stale shell accepted for presentation")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "stale or reconnect launch stays silent")
	var reused: Projectile = Pool.acquire(game.POOL_KEY)
	t.equal(reused.shell_kind, 0, "recycled projectile has no stale weapon kind")
	var serial := reused.launch_serial
	reused.fire(Vector3(100, 4, 100), Vector3.FORWARD, 0, 22, 25, 52)
	t.equal(reused.shell_kind, 0, "standard fire resets special kind")
	t.equal(reused.launch_serial, serial + 1, "reused shell has a fresh launch generation")
	Pool.release(game.POOL_KEY, reused)
	game.on_round_start()
	packet = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.round = 1
	packet.phase = MatchPhase.P.INTRO
	t.ok(replica.accept(packet, 4, "tank_arena"), "round reset world accepted")
	replica.render(scene, 0.016)
	t.ok(replica._tank.shots.is_empty(), "round reset clears old shell visuals")
	for slot in 4:
		t.equal(game.armor[slot], 100, "round restores armor")
		t.equal(game.ammo[slot], 0, "round clears ammo")
	for crate in game.crates:
		t.ok(crate.node.visible and crate.cooldown == 0, "round restores crates")
	AudioManager.enabled = enabled
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _test_ammo_perception(t: TestHarness, scene: Node) -> void:
	var game = scene.controller
	var me: Fighter = scene.ctx.fighter(0)
	var origin := me.global_position
	var camera_transform: Transform3D = scene.camera.global_transform
	var fighter_visibility: Array[bool] = []
	for fighter in scene.ctx.fighters:
		fighter_visibility.append(fighter.visible)
		fighter.hide()
	me.show()
	me.global_position = scene.ctx.arena_center() + Vector3.UP
	# The synthetic ammo venue must move with its follow-camera subject.
	scene.camera.global_position += me.global_position - origin
	var saved: Array[Dictionary] = []
	for crate in game.crates:
		saved.append({"position": crate.node.global_position, "pos": crate.pos,
			"cooldown": crate.cooldown, "visible": crate.node.visible})
		crate.cooldown = 0.0
		crate.node.hide()
	var first: Node3D = game.crates[0].node
	var second: Node3D = game.crates[1].node
	first.global_position = me.global_position + Vector3(2, 0, 0)
	second.global_position = me.global_position + Vector3(4, 0, 0)
	game.crates[0].pos = first.global_position
	game.crates[1].pos = second.global_position
	second.show()
	t.equal(game.crate_target(0), second.global_position, "hidden ammo cannot displace a visible target")
	var brain := AmmoSteeringProbe.new()
	brain.configure(0, scene.ctx, 3, 117)
	# This fixture isolates steering/availability; difficulty delays are tested
	# with all four profiles in test_tank_crate_perception.gd.
	brain.reaction_time = 0.0
	brain.controller = game
	t.ok(brain.can_observe(second), "ammo fixture's visible crate is inside the observation view")
	brain.decide(0.0)
	t.equal(brain.destination, second.global_position, "unarmed tank collects visible ammo without a visible rival")
	first.show()
	t.ok(brain.can_observe(first), "near ammo fixture is observable before testing route obstruction")
	brain.blocked = first.global_position
	brain.decide(0.0)
	t.equal(brain.destination, second.global_position, "blocked nearest crate cannot mask reachable ammo")
	brain.blocked = Vector3(INF, INF, INF)
	game.crates[0].cooldown = 1.0
	brain.decide(0.0)
	t.equal(brain.destination, second.global_position, "collected crate cannot attract a bot before respawn")
	game.crates[0].cooldown = 0.0
	brain.decide(0.0)
	t.equal(brain.destination, first.global_position, "visible respawn restores nearest ammo target")
	game.crates[0].pos = me.global_position + Vector3(99, 0, 0)
	t.equal(game.crate_target(0), first.global_position, "target uses rendered location rather than stored coordinates")
	var parent := Node3D.new()
	game.add_child(parent)
	first.reparent(parent, true)
	parent.hide()
	brain.decide(0.0)
	t.equal(brain.destination, second.global_position, "hidden crate parent suppresses the ammo cue")
	first.reparent(game, true)
	parent.queue_free()
	game.ammo[0] = 3
	t.equal(game.crate_target(0), me.global_position, "armed tank does not seek another weapon")
	brain.destination = Vector3(INF, INF, INF)
	brain.decide(0.0)
	t.ok(not brain.destination.is_equal_approx(first.global_position), "armed bot does not chase ammo")
	game.ammo[0] = 0
	first.hide()
	second.hide()
	t.equal(game.crate_target(0), me.global_position, "no visible ammo returns no movement target")
	brain.destination = Vector3(INF, INF, INF)
	brain.decide(0.0)
	t.equal(brain.destination, scene.ctx.arena_center(), "lost observations choose known arena center instead of stale steering")
	var idle = load("res://src/ai/brains/tank_brain.gd").new()
	idle.configure(0, scene.ctx, 3, 117)
	idle.controller = game
	idle.move = Vector2(0.6, -0.9)
	idle.decide(0.0)
	t.equal(idle.move, Vector2.ZERO, "bot already at search center clears previous driving input")
	var queued := Node3D.new()
	game.add_child(queued)
	queued.global_position = me.global_position + Vector3.RIGHT
	game.crates.append({"node": queued, "pos": queued.global_position, "cooldown": 0.0})
	queued.queue_free()
	t.equal(game.crate_target(0), me.global_position, "queued ammo cannot become a target")
	game.crates.pop_back()
	for index in game.crates.size():
		var crate: Dictionary = game.crates[index]
		crate.node.global_position = saved[index].position
		crate.pos = saved[index].pos
		crate.cooldown = saved[index].cooldown
		crate.node.visible = saved[index].visible
	for index in scene.ctx.player_count():
		scene.ctx.fighter(index).visible = fighter_visibility[index]
	me.global_position = origin
	scene.camera.global_transform = camera_transform


func _test_peer_corridor(t: TestHarness, host: Node, scene: Node) -> void:
	var peer: Node = load("res://tests/network_peer.gd").new()
	peer.game = scene
	var origin := Vector3(100, 1, 100)
	var target := Vector3(100, 1, 110)
	t.ok(peer._tank_clear_path(origin, target), "empty vehicle-width corridor permits direct pursuit")
	peer.tank_route = PackedVector3Array([Vector3(0, 0, 6)])
	t.equal(peer._tank_waypoint(origin, target), target, "clear combat corridor bypasses the road detour")
	t.equal(peer.tank_route.size(), 0, "direct pursuit discards a stale road route")
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.4
	collision.shape = box
	barrier.add_child(collision)
	host.add_child(barrier)
	barrier.global_position = Vector3(101, 2, 105)
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	t.ok(not peer._tank_clear_path(origin, target), "side barrier blocks an ATV corridor even when the center ray is clear")
	barrier.global_position = Vector3(100, 2, 105)
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	t.ok(not peer._tank_clear_path(origin, target), "center barrier also retains road navigation")
	barrier.free()
	peer.free()


func _test_routing_clock(t: TestHarness, scene: Node) -> void:
	var me: Fighter = scene.ctx.fighter(0)
	var origin := me.global_position
	var world = scene.arena.get_meta("tank_world")
	var routing := RoutingWorld.new()
	scene.arena.set_meta("tank_world", routing)
	me.global_position = scene.ctx.arena_center() + Vector3.UP
	var brain := RouteSteeringProbe.new()
	brain.configure(0, scene.ctx, 3, 117)
	brain.controller = scene.controller
	brain.decide(1.0 / 60.0)
	t.equal(routing.calls, 1, "blocked route is obtained on the first decision")
	t.equal(brain.destination, routing.waypoint, "route follows the next unreached road point")
	brain._time = 0.5
	brain.decide(1.0 / 60.0)
	t.equal(routing.calls, 1, "route cache avoids a graph query every decision")
	brain._time = 1.01
	brain.decide(1.0 / 60.0)
	t.equal(routing.calls, 2, "route refresh follows simulation time rather than decision-count times physics delta")
	me.global_position = routing.waypoint
	brain._time = 1.1
	brain.decide(1.0 / 60.0)
	t.equal(brain.destination, brain.next_target, "reached final road point continues toward observed rival")
	brain.move = Vector2(0.6, -0.9)
	brain.on_round_start()
	t.equal(brain.move, Vector2.ZERO, "new round resets driving input through the shared brain lifecycle")
	brain.decide(1.0 / 60.0)
	t.equal(routing.calls, 3, "new round discards the previous round's cached route immediately")
	me.global_position = origin
	scene.arena.set_meta("tank_world", world)


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false
