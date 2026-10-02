extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Sovereign = preload("res://src/net/sovereign_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("sovereign network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_sovereign", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 121), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	var fighter: Fighter = source.ctx.fighter(0)
	fighter.global_position = game._core.global_position
	fighter._attack_time = 0.2
	game._check_core_hits()
	fighter._attack_time = 0.0
	t.equal(game.boss_health, 1440.0, "real host core swing credits damage")
	game._throw_orbs()
	game.telegraph(Vector3(6, 0, 0), 4.2, 1.35, func(_pos, _radius): pass)
	var packet := _packet(source)
	var replica := Replica.new()
	var sample_time := {"now": 1000}
	replica.receive_clock = func(): return sample_time.now
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "actual host world accepted")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("sovereign-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual capture writable")
	if capture != null:
		capture.store_string(JSON.stringify(packet.world))
		capture.close()
	for count in [2, 3, 4]: t.ok(Sovereign.valid(packet.world, count), "bounded roster accepted")
	for field in ["volleys", "returns"]:
		for value in [-1, 0.5, true, INF, NAN, "1", null, 1000001]:
			var invalid := packet.duplicate(true)
			invalid.world[field] = value
			t.ok(not Sovereign.valid(invalid.world, 4), "bounded integer orb event generation")
	var excess_returns := packet.duplicate(true)
	excess_returns.world.returns = 5
	t.ok(not Sovereign.valid(excess_returns.world, 4), "cannot return more orbs than launched")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "missing world field rejected")
	for field in packet.world.boss.keys():
		var bad := packet.duplicate(true)
		bad.world.boss.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "missing boss field rejected")
	for entry in [{"key": "health", "values": [-1, 1500.1, true, "1440", null, NAN, INF]},
		{"key": "phase", "values": [-1, 1, 0.5, true]}, {"key": "defeated", "values": [true, 0]},
		{"key": "rotation", "values": [[0, PI + 0.01, 0]]}]:
		for value in entry.values:
			var bad := packet.duplicate(true)
			bad.world.boss[entry.key] = value
			t.ok(not replica.accept(bad, 4, "boss_sovereign"), "invalid boss field rejected")
	for group in ["warnings", "orbs"]:
		for field in packet.world[group][0].keys():
			var bad := packet.duplicate(true)
			bad.world[group][0].erase(field)
			t.ok(not replica.accept(bad, 4, "boss_sovereign"), "missing object field rejected")
		for id in ["", "01", "-1", "1.0", "1000000000000000000", 1, null]:
			var bad := packet.duplicate(true)
			bad.world[group][0].id = id
			t.ok(not replica.accept(bad, 4, "boss_sovereign"), "invalid object id rejected")
		var bad := packet.duplicate(true)
		bad.world[group].append(bad.world[group][0].duplicate(true))
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "duplicate object rejected")
		bad = packet.duplicate(true)
		bad.world[group][0].extra = 1
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "extra object field rejected")
		bad = packet.duplicate(true)
		bad.world[group] = []
		for index in (65 if group == "warnings" else 33):
			var row: Dictionary = packet.world[group][0].duplicate(true)
			row.id = str(index + 10)
			bad.world[group].append(row)
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "object count bounded")
	for value in [-1, 2.801, true, NAN, INF, "1", null]:
		var bad := packet.duplicate(true)
		bad.world.recovery = value
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "invalid recovery rejected")
	for value in [true, 1, "false", null]:
		var bad := packet.duplicate(true)
		bad.world.shielded = value
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "invalid or out-of-phase shield rejected")
	for value in [0, 1, "false", null]:
		var bad := packet.duplicate(true)
		bad.world.orbs[0].returned = value
		t.ok(not replica.accept(bad, 4, "boss_sovereign"), "returned is boolean only")
	var bad := packet.duplicate(true)
	bad.world.orbs[0].id = bad.world.warnings[0].id
	t.ok(not replica.accept(bad, 4, "boss_sovereign"), "cross-type duplicate rejected")
	t.equal(replica.target, packet, "invalid world cannot overwrite baseline")
	guest.controller._raise_shield()
	guest.controller._throw_orbs()
	var probe := {"landed": false}
	guest.controller.telegraph(Vector3.ZERO, 4.2, 0.1, func(_p, _r): probe.landed = true)
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = 0
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "first baseline never replays historical audio")
	await host.get_tree().process_frame
	var view: Node = replica._sovereign
	t.ok(guest.controller.presentation_only, "guest is presentation only")
	t.equal(view.orbs.size(), 4, "host orbs rendered")
	t.equal(view.warnings.size(), 1, "host warning rendered")
	t.equal(_colliders(view), 0, "view has no collision objects")
	t.empty(guest.controller._orbs, "guest has no local orb physics")
	t.empty(guest.controller._telegraphs, "guest has no local warning callbacks")
	t.ok(not guest.controller._shield.visible and not view.shield.visible, "old shield retired and host shield state shown")
	var position: Vector3 = guest.controller.boss_node.global_position
	var scores := Array(guest.ctx.scores).duplicate()
	guest.ctx.fighter(0).global_position = guest.controller._core.global_position
	guest.ctx.fighter(0)._attack_time = 0.2
	guest.controller.tick(10)
	guest.controller.boss_think(10)
	guest.controller._pursuit(10)
	guest.controller._siege(10)
	guest.controller._raise_shield()
	guest.controller._throw_orbs()
	guest.controller._tick_orbs(10)
	guest.controller._collapse(10)
	guest.controller._check_core_hits()
	guest.controller.damage_boss(1500, 0)
	guest.controller.on_phase_changed(2)
	guest.controller.boss_reset_round()
	t.equal(guest.controller.boss_health, 1440.0, "guest cannot damage boss or reset health")
	t.equal(guest.controller.boss_node.global_position, position, "guest cannot pursue fighters")
	t.equal(Array(guest.ctx.scores), scores, "guest cannot award score")
	t.ok(not guest.ctx.early_finish and not probe.landed, "guest cannot finish or fire callbacks")
	t.empty(guest.controller._orbs, "guest cannot spawn or simulate orbs")
	t.empty(guest.controller._telegraphs, "guest cannot spawn damaging warnings")
	var previous_warning: Node = view.warnings.values()[0]
	game._telegraphs[0].radius = 5.0
	packet = _packet(source)
	sample_time.now = 1050
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "changed host warning radius accepted")
	replica.render(guest, 0.016)
	t.ok(view.warnings.values()[0] != previous_warning, "warning geometry replaced when radius changes")
	await host.get_tree().process_frame
	t.ok(not is_instance_valid(previous_warning), "replaced warning geometry freed")
	game.damage_boss(500, 0)
	game._raise_shield()
	packet = _packet(source)
	sample_time.now = 2000
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "phase two shield accepted")
	replica.render(guest, 0.016)
	t.ok(view.shield.visible and guest.controller._shielded, "host shield displayed")
	for index in game._orbs.size():
		game._orbs[index].node.global_position = game.boss_node.global_position + Vector3(30, 2.2, 0)
	game._orbs[0].node.global_position = game.boss_node.global_position + Vector3(8, 2.2, 0)
	fighter.global_position = game._orbs[0].node.global_position
	fighter._attack_time = 0.2
	game._tick_orbs(0.0)
	fighter._attack_time = 0.0
	t.equal(game.orb_return_sequence, 1, "actual swing increments return generation")
	packet = _packet(source)
	sample_time.now = 3000
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "orb return accepted")
	t.equal(replica.received_at - replica._event_received_at, 1000, "fresh orb sample at exact feedback boundary")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh orb return plays once")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate orb return is quiet")
	game.damage_boss(1, 0)
	packet = _packet(source)
	sample_time.now = 4001
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "stale damage still updates state")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "1001 ms sample does not replay historical feedback")
	game._clear_orbs()
	game._clear_telegraphs()
	game.damage_boss(1500, 0)
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "actual host defeat accepted")
	replica.render(guest, 0.016)
	t.ok(guest.controller.boss_defeated and not guest.controller.boss_node.visible and not view.shield.visible, "defeat hides boss and shield")
	t.empty(view.orbs, "removed orb views pruned")
	t.empty(view.warnings, "removed warning views pruned")
	source._start_next_round()
	t.equal(game.orb_volley_sequence, 0, "next round resets volley generation")
	t.equal(game.orb_return_sequence, 0, "next round resets return generation")
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_sovereign"), "actual next round accepted")
	replica.render(guest, 0.016)
	t.equal(guest.controller.boss_health, 1500.0, "new round restores health")
	t.ok(guest.controller.boss_node.visible and not guest.controller.boss_defeated, "new round restores visible boss")
	game._throw_orbs()
	fighter.global_position = game.boss_node.global_position + Vector3(0, 2.2, 0)
	fighter._attack_time = 0.2
	game._tick_orbs(0.0)
	fighter._attack_time = 0.0
	packet = _packet(source)
	t.empty(packet.world.orbs, "instant returns can disappear before the next snapshot")
	t.equal(packet.world.volleys, 1, "snapshot preserves volley despite absent objects")
	t.equal(packet.world.returns, 4, "snapshot preserves actual instant return events")
	t.ok(Sovereign.valid(packet.world, 4), "instant-return snapshot remains valid")
	var reconnect := Replica.new()
	t.ok(reconnect.accept(packet, 4, "boss_sovereign"), "replacement accepts current host baseline")
	reconnect._last_phase = MatchPhase.P.PLAYING
	reconnect._last_round = 1
	voice = AudioManager._next_voice
	reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "replacement baseline stays quiet")
	await host.get_tree().process_frame
	var views := 0
	for node in guest.ctx.world_root.get_children():
		if node.get_script() == Sovereign: views += 1
	t.equal(views, 1, "replacement retires previous view")
	for scene in scenes:
		scene.teardown()
		scene.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _packet(scene: Node) -> Dictionary:
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	return packet


func _colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children(): count += _colliders(child)
	return count
