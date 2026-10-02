extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("crate network presentation")
	for id in ["crate_smash", "lab_crates"]:
		var cfg := MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 111)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
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


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false
