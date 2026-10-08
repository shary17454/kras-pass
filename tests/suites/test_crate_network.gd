extends RefCounted

class SpawnProbe extends "res://src/minigames/crate_smash.gd":
	var blocked := true
	var attempts := 0
	func _spot_is_free(_position: Vector3) -> bool:
		attempts += 1
		return not blocked


func run(t: TestHarness, host: Node) -> void:
	t.suite("crate network presentation")
	for id in ["crate_smash", "lab_crates"]:
		var cfg := MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 111)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		if id == "crate_smash":
			var fighter: Fighter = scene.ctx.fighter(0)
			var old_position := fighter.global_position
			var old_alive: bool = scene.ctx.alive[0]
			var capsule := (fighter.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D
			var old_radius := capsule.radius
			var candidate := Vector3(1000, 0.75, 1000)
			fighter.global_position = candidate
			t.ok(not game._spot_is_free(candidate), "crate cannot appear through a live player's body")
			var near_edge := candidate + Vector3.RIGHT * 1.5
			t.ok(game._spot_is_free(near_edge), "ordinary body leaves distant spawn space available")
			capsule.radius = 0.9
			t.ok(not game._spot_is_free(near_edge), "spawn clearance follows actual enlarged collision radius")
			scene.ctx.alive[0] = false
			t.ok(game._spot_is_free(candidate), "eliminated player does not reserve spawn space")
			fighter.global_position = old_position
			scene.ctx.alive[0] = old_alive
			capsule.radius = old_radius
			var spawn_probe := SpawnProbe.new()
			spawn_probe.ctx = scene.ctx
			var children_before: int = scene.ctx.world_root.get_child_count()
			spawn_probe._spawn_crate()
			t.equal(spawn_probe.attempts, 20, "blocked spawn search is bounded")
			t.ok(spawn_probe._crates.is_empty(), "exhausted spawn cannot append an overlapping crate")
			t.equal(scene.ctx.world_root.get_child_count(), children_before, "exhausted spawn cannot add orphan world nodes")
			spawn_probe.cleanup()
			await host.get_tree().process_frame
			spawn_probe.blocked = false
			spawn_probe.attempts = 0
			spawn_probe._spawn_crate()
			t.equal(spawn_probe.attempts, 1, "spawn retries normally when a free spot becomes available")
			t.equal(spawn_probe._crates.size(), 1, "a deferred crate can be created later")
			spawn_probe.cleanup()
			spawn_probe.free()
			await host.get_tree().process_frame
		if id == "lab_crates":
			await _mixed_break_feedback(t, host)
		if id == "lab_crates":
			game._volley(0, Vector3(2, 1, 3))
		var replica = load("res://src/net/match_replica.gd").new()
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		packet.phase = MatchPhase.P.PLAYING
		t.ok(replica.accept(packet, 4, id), id + " JSON snapshot accepted")
		for field in packet.world.keys():
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, 4, id), "reject missing " + field)
		for value in [null, true, "1", NAN, INF, -1, 0.5, 1000001]:
			var bad := packet.duplicate(true)
			bad.world.break_sequence = value
			t.ok(not replica.accept(bad, 4, id), "reject invalid event sequence")
		for value in ["", "0", "01", "+1", "-1", "1.0", 1, "1000000000000000000"]:
			var bad := packet.duplicate(true)
			bad.world.crates[0].id = value
			t.ok(not replica.accept(bad, 4, id), "reject noncanonical identity")
		var duplicate := packet.duplicate(true)
		duplicate.world.crates[1].id = duplicate.world.crates[0].id
		t.ok(not replica.accept(duplicate, 4, id), "reject duplicate identity")
		var wrong := packet.duplicate(true)
		wrong.world.crates[0].kind = 3
		t.ok(not replica.accept(wrong, 4, id), "reject invalid crate type")
		for changes in [{"extra": 1}, {"break_position": [NAN, 0, 0]}, {"break_kind": 5}]:
			var bad := packet.duplicate(true)
			bad.world.merge(changes, true)
			t.ok(not replica.accept(bad, 4, id), "reject malformed feedback")
		for value in [null, {}, [], packet.world.break_events.slice(0, 4), packet.world.break_events + [packet.world.break_events[0]]]:
			var bad := packet.duplicate(true)
			bad.world.break_events = value
			t.ok(not replica.accept(bad, 4, id), "reject malformed event lane count")
		for changes in [{"sequence": -1}, {"sequence": true}, {"sequence": INF}, {"sequence": 0.5}, {"sequence": 1000001}, {"position": [0, NAN, 0]}, {"extra": 1}]:
			var bad := packet.duplicate(true)
			bad.world.break_events[0].merge(changes, true)
			t.ok(not replica.accept(bad, 4, id), "reject malformed event lane")
		var inconsistent := packet.duplicate(true)
		inconsistent.world.break_events[0].sequence = 1
		t.ok(not replica.accept(inconsistent, 4, id), "reject event totals inconsistent with break sequence")
		if id == "crate_smash":
			var bad := packet.duplicate(true)
			bad.world.break_sequence = 2
			bad.world.break_events[0].sequence = 1
			bad.world.break_events[3].sequence = 1
			t.ok(not replica.accept(bad, 4, id), "non-lab world cannot inject a volley event")
		var excess := packet.duplicate(true)
		excess.world.crates.append(excess.world.crates[0].duplicate(true))
		t.ok(not replica.accept(excess, 4, id), "reject oversized crate field")
		var sample := {"id": "20", "position": [2, 1, 3], "direction": [1, 0, 0], "shooter": 0}
		if id == "lab_crates":
			for changes in [{"id": packet.world.crates[0].id}, {"direction": [0, 0, 0]},
				{"direction": [0, 1, 0]}, {"direction": [INF, 0, 0]}, {"shooter": 4},
				{"shooter": true}, {"position": [0, 0, 10001]}, {"extra": 1}]:
				var bad := packet.duplicate(true)
				var shot := sample.duplicate(true)
				shot.merge(changes, true)
				bad.world.shots = [shot]
				t.ok(not replica.accept(bad, 4, id), "reject invalid lab projectile")
		else:
			var bad := packet.duplicate(true)
			bad.world.shots = [sample]
			t.ok(not replica.accept(bad, 4, id), "non-lab game cannot inject projectiles")
			bad = packet.duplicate(true)
			bad.world.crates[0].kind = 2
			t.ok(not replica.accept(bad, 4, id), "non-lab game cannot inject weapon crates")
		t.equal(replica.target, packet, "invalid data cannot replace accepted world")
		var old: Array = []
		for entry in game._crates:
			old.append(entry.node)
		replica.render(scene, 0.1)
		t.ok(game._crates.is_empty(), "guest removes independently generated field")
		for body in old:
			t.equal(body.collision_layer, 0, "guest removes procedural collision")
		t.equal(replica._crates.crates.size(), packet.world.crates.size(), "all host crates are visible")
		t.equal(replica._crates.shots.size(), packet.world.shots.size(), "all host shots are visible")
		t.ok(not _has_collision(replica._crates), "guest views cannot collide or inflict damage")
		var retained: Node = replica._crates.crates[packet.world.crates[0].id]
		var scores := Array(scene.ctx.scores)
		var timer: float = game._spawn_timer
		for repeat in 8:
			replica.render(scene, 1.0)
		t.equal(Array(scene.ctx.scores), scores, "render cannot score")
		t.near(game._spawn_timer, timer, 0.00001, "render cannot spawn or advance rules")
		t.equal(replica._crates.crates[packet.world.crates[0].id], retained, "stable identity reuses its view")
		packet.world.break_sequence += 1
		packet.world.break_kind = 0
		packet.world.break_position = packet.world.crates[0].position
		packet.world.break_events[0].sequence += 1
		packet.world.break_events[0].position = packet.world.break_position.duplicate()
		packet.world.crates.pop_front()
		AudioManager._last_played.erase("crate_break")
		t.ok(replica.accept(packet, 4, id), "accept broken crate")
		replica.render(scene, 0.1)
		t.ok(not retained.visible and retained.is_queued_for_deletion(), "broken crate disappears immediately")
		if AudioManager.enabled:
			t.ok(AudioManager._last_played.has("crate_break"), "new break produces feedback")
		AudioManager._last_played.erase("crate_break")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("crate_break"), "duplicate state cannot replay feedback")
		packet.world.break_sequence += 1
		packet.world.break_events[0].sequence += 1
		t.ok(replica.accept(packet, 4, id), "accept reconnect world")
		replica._event_received_at = replica.received_at - 1501
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("crate_break"), "reconnect suppresses old feedback")
		packet.world.shots.clear()
		t.ok(replica.accept(packet, 4, id), "accept expired volley")
		replica.render(scene, 0.1)
		t.ok(replica._crates.shots.is_empty(), "expired shots removed")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _mixed_break_feedback(t: TestHarness, host: Node) -> void:
	var audio_enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var cfg := MatchConfig.build("lab_crates", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 111)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game: Node = scene.controller
	var replica = load("res://src/net/crate_replica.gd").new()
	scene.ctx.world_root.add_child(replica)
	var baseline: Dictionary = replica.capture(game, true)
	replica.render(game, baseline, 0.016, true, false)
	# Controlled feedback ordering, not a naturally played match.
	game._record_break(3, Vector3(2, 1, 3))
	game._record_break(0, Vector3(4, 1, 5))
	var mixed: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(game, true)))
	t.ok(replica.valid(mixed, 4, true), "actual mixed event capture survives strict JSON validation")
	t.equal(int(mixed.break_events[3].sequence), 1, "volley lane survives a later normal break")
	AudioManager._last_played.erase("shoot")
	AudioManager._last_played.erase("crate_break")
	replica.render(game, mixed, 0.016, false, true)
	t.ok(AudioManager._last_played.has("shoot"), "later normal crate does not erase volley feedback")
	t.ok(AudioManager._last_played.has("crate_break"), "mixed break snapshot retains normal crate feedback")
	AudioManager._last_played.erase("shoot")
	AudioManager._last_played.erase("crate_break")
	replica.render(game, mixed, 0.016, false, true)
	t.ok(not AudioManager._last_played.has("shoot") and not AudioManager._last_played.has("crate_break"), "mixed break duplicate cannot replay either feedback")
	game._record_break(3, Vector3(6, 1, 7))
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(game, true)))
	replica.render(game, resumed, 0.016, true, false)
	replica.render(game, resumed, 0.016, false, true)
	t.ok(not AudioManager._last_played.has("shoot"), "reconnect baseline suppresses retained volley feedback")
	AudioManager.enabled = audio_enabled
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false
