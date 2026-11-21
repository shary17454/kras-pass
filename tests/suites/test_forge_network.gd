extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Forge = preload("res://src/net/forge_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("forge network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_forge", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 121), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	for scene in scenes:
		var forge: Node = scene.controller
		var collar: MeshInstance3D = forge.boss_node.get_node("IntakeCollar")
		var ring := collar.mesh as TorusMesh
		t.ok(ring != null and ring.inner_radius > 2.6, "feeding marker clears opaque furnace shell")
		t.ok(ring != null and is_equal_approx(ring.outer_radius, 2.9), "marker matches existing cap silhouette")
		t.equal(collar.position.y, 1.5, "feeding marker retains target height")
		t.equal(forge._intake.position, Vector3(0, 1.5, 0), "visual polish does not move feeding anchor")
		t.equal(collar.get_child_count(), 0, "feeding marker has no collision children")
	game._lob_crate()
	game._lob_crate()
	var fighter: Fighter = source.ctx.fighter(0)
	fighter.global_position = game._crates[0].global_position
	fighter._attack_time = 0.2
	game._check_feeding()
	fighter._attack_time = 0.0
	t.equal(game._crates.size(), 1, "actual swing removes one host crate")
	game._slag[0].node.global_position = game._intake.global_position
	game._tick_slag(0.0)
	t.equal(game.boss_health, 780.0, "actual host slag damages intake")
	t.equal(game.damage_sequence, 1, "host damage records sampled feedback")
	game._spawn_slag(game.boss_node.global_position + Vector3(5, 0, 0), 0)
	game.strike(Vector3(6, 0, 0), 3.4)
	game.telegraph(Vector3(5, 0, 0), 3.4, 1.3, func(_pos, _radius): pass)
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	var replica := Replica.new()
	var sample_time := {"now": 1000}
	replica.receive_clock = func(): return sample_time.now
	t.ok(replica.accept(packet, 4, "boss_forge"), "actual host forge JSON accepted")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("forge-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual forge capture writable")
	if capture != null:
		capture.store_string(JSON.stringify(packet.world))
		capture.close()
	for count in [2, 3, 4]: t.ok(Forge.valid(packet.world, count), "forge supports bounded online roster")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_forge"), "missing world field rejected")
	for field in packet.world.boss.keys():
		var bad := packet.duplicate(true)
		bad.world.boss.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_forge"), "missing boss field rejected")
	for entry in [{"key": "health", "values": [-1, 900.1, true, "780", null, NAN, INF]},
		{"key": "phase", "values": [-1, 1, 0.5, true]}, {"key": "defeated", "values": [true, 0, "false"]},
		{"key": "damage", "values": [-1, 0.5, 1000001]}, {"key": "strike", "values": [-1, 0.5, 1000001]},
		{"key": "strike_radius", "values": [-1, 100.1, true]}, {"key": "rotation", "values": [[0, PI + 0.01, 0]]}]:
		for value in entry.values:
			var bad := packet.duplicate(true)
			bad.world.boss[entry.key] = value
			t.ok(not replica.accept(bad, 4, "boss_forge"), "invalid boss field rejected")
	for group in ["warnings", "crates", "slag"]:
		for field in packet.world[group][0].keys():
			var bad := packet.duplicate(true)
			bad.world[group][0].erase(field)
			t.ok(not replica.accept(bad, 4, "boss_forge"), "missing object field rejected")
		for id in ["", "01", "-1", "1.0", "1000000000000000000", 1, null]:
			var bad := packet.duplicate(true)
			bad.world[group][0].id = id
			t.ok(not replica.accept(bad, 4, "boss_forge"), "noncanonical object id rejected")
		var bad := packet.duplicate(true)
		bad.world[group].append(bad.world[group][0].duplicate(true))
		t.ok(not replica.accept(bad, 4, "boss_forge"), "duplicate object rejected")
		bad = packet.duplicate(true)
		bad.world[group][0].extra = 1
		t.ok(not replica.accept(bad, 4, "boss_forge"), "extra object field rejected")
		bad = packet.duplicate(true)
		bad.world[group] = []
		for index in (65 if group == "warnings" else 97):
			var row: Dictionary = packet.world[group][0].duplicate(true)
			row.id = str(index + 10)
			bad.world[group].append(row)
		t.ok(not replica.accept(bad, 4, "boss_forge"), "object population bounded")
	for patch in [{"left": -1}, {"left": 2}, {"total": 0}, {"total": 61}, {"radius": 0.24}, {"radius": 101}]:
		var bad := packet.duplicate(true)
		bad.world.warnings[0].merge(patch, true)
		t.ok(not replica.accept(bad, 4, "boss_forge"), "invalid warning bounds rejected")
	for patch in [{"life": 0}, {"life": 6.01}, {"by": -1}, {"by": 4}, {"by": true}]:
		var bad := packet.duplicate(true)
		bad.world.slag[0].merge(patch, true)
		t.ok(not replica.accept(bad, 4, "boss_forge"), "invalid slag bounds rejected")
	var bad := packet.duplicate(true)
	bad.world.slag[0].id = bad.world.crates[0].id
	t.ok(not replica.accept(bad, 4, "boss_forge"), "cross-type duplicate rejected")
	bad = packet.duplicate(true)
	bad.world.intake = [0, 0, INF]
	t.ok(not replica.accept(bad, 4, "boss_forge"), "invalid intake rotation rejected")
	t.equal(replica.target, packet, "rejected snapshots cannot replace valid host baseline")
	var probe := {"landed": false}
	guest.controller._lob_crate()
	guest.controller._spawn_slag(Vector3(4, 0, 0), 0)
	guest.controller.telegraph(Vector3.ZERO, 2.0, 0.1, func(_pos, _radius): probe.landed = true)
	guest.controller.fire_shot(Vector3.ZERO, Vector3.FORWARD, 10, 10, 30)
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = 0
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "initial boss baseline has no historical feedback")
	await host.get_tree().process_frame
	var view: Node = replica._forge
	t.ok(guest.controller.presentation_only, "guest is presentation-only")
	t.equal(guest.controller.boss_health, 780.0, "guest HUD reads authoritative boss health")
	t.empty(guest.controller._telegraphs, "guest has no authoritative warning callbacks")
	t.empty(guest.controller._crates, "guest has no physical crates")
	t.empty(guest.controller._slag, "guest has no authoritative slag")
	t.empty(guest.controller._shots, "guest has no physical boss shots")
	t.equal(view.warnings.size(), 1, "host warning has a visible view")
	t.equal(view.crates.size(), 1, "host crate has a visible view")
	t.equal(view.slag.size(), 1, "host slag has a visible view")
	t.equal(_colliders(view), 0, "forge world views cannot collide")
	var health: float = guest.controller.boss_health
	var scores := Array(guest.ctx.scores).duplicate()
	guest.controller.tick(5.0)
	guest.controller.boss_think(5.0)
	guest.controller.damage_boss(900, 0)
	guest.controller._defeat()
	guest.controller.strike(Vector3.ZERO, 10)
	guest.controller._tick_telegraphs(10)
	guest.controller._tick_shots(10)
	guest.controller._lob_crate()
	guest.controller._stomp()
	guest.controller._spawn_slag(Vector3.ZERO, 0)
	guest.controller._tick_slag(10)
	guest.controller._check_feeding()
	guest.controller.on_phase_changed(2)
	guest.controller.on_round_start()
	guest.controller.boss_reset_round()
	t.equal(guest.controller.boss_health, health, "guest callbacks cannot reset or damage boss")
	t.equal(Array(guest.ctx.scores), scores, "guest callbacks cannot award points")
	t.ok(not guest.ctx.early_finish, "guest cannot end the match")
	t.ok(not probe.landed, "guest's prior warning callback never fires")
	t.equal(guest.controller.damage_sequence, 1, "guest cannot invent damage feedback")
	t.equal(guest.controller.strike_sequence, 1, "guest cannot invent strike feedback")
	t.empty(guest.controller._crates, "guest callbacks do not spawn physical crates")
	game._slag[0].node.global_position = game._intake.global_position
	game._tick_slag(0.0)
	packet = _packet(source)
	sample_time.now = 2000
	t.ok(replica.accept(packet, 4, "boss_forge"), "second actual intake hit accepted")
	t.equal(replica.received_at - replica._event_received_at, 1000, "fresh sample at exact feedback boundary")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh sampled intake hit plays once")
	t.equal(guest.controller.boss_health, 660.0, "guest health tracks second host hit")
	t.empty(view.slag, "consumed host slag view removed")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate feedback stays quiet without debounce")
	game.damage_boss(1, 0)
	packet = _packet(source)
	sample_time.now = 3001
	t.ok(replica.accept(packet, 4, "boss_forge"), "stale damage state still accepted")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "1001 ms sample updates state without historical sound")
	var reconnect := Replica.new()
	t.ok(reconnect.accept(packet, 4, "boss_forge"), "reconnect accepts current host state")
	reconnect._last_phase = MatchPhase.P.PLAYING
	reconnect._last_round = 0
	reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "reconnect does not replay old damage")
	await host.get_tree().process_frame
	var views := 0
	for node in guest.ctx.world_root.get_children():
		if node.get_script() == Forge: views += 1
	t.equal(views, 1, "replacement replica retires old forge view")
	replica = reconnect
	view = reconnect._forge
	game.damage_boss(900, 0)
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_forge"), "actual host defeat accepted")
	replica.render(guest, 0.016)
	t.ok(guest.controller.boss_defeated and not guest.controller.boss_node.visible, "only host defeat hides guest boss")
	t.equal(guest.controller.phase, 2, "host final phase copied without guest callbacks")
	source._start_next_round()
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_forge"), "host next round accepted")
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = 1
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "next-round baseline is quiet")
	t.equal(guest.controller.boss_health, 900.0, "host next round restores guest boss health")
	t.ok(guest.controller.boss_node.visible and not guest.controller.boss_defeated, "host next round restores visible boss")
	t.empty(view.warnings, "next round removes old warning views")
	t.empty(view.crates, "next round removes old crate views")
	t.empty(view.slag, "next round removes old slag views")
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
