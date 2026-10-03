extends RefCounted

const View = preload("res://src/net/colossus_replica.gd")
const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("colossus network carved presentation")
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	for slot in 4:
		source.ctx.fighter(slot).global_position = Vector3(6, 0, 0) if slot == 0 else Vector3(80 + slot, 0, 0)
	game._slam()
	game._tick_telegraphs(2.0)
	t.equal(game._craters.size(), 1, "actual slam creates host crater")
	t.equal(game.strike_sequence, 1, "actual slam records strike")
	t.ok(not source.arena.is_inside(Vector3(6, 0, 0)), "host ground is carved at fist")
	var fighter: Fighter = source.ctx.fighter(0)
	fighter.global_position = Vector3(9.55, 0, 0)
	fighter._attack_time = 0.2
	game._check_arm_hits()
	fighter._attack_time = 0.0
	t.equal(game.boss_health, 745.0, "actual rim attack damages exposed host arm")
	game.telegraph(Vector3(-4, 0, 2), 3.0, 1.2, func(_pos, _radius): pass)
	var world: Dictionary = JSON.parse_string(JSON.stringify(View.capture(game)))
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	var replica := Replica.new()
	t.equal(packet.world, world, "shared snapshot capture includes actual colossus world")
	t.ok(replica.accept(packet, 4, "boss_colossus"), "shared snapshot validates colossus packet")
	var malformed := packet.duplicate(true)
	malformed.world.exposed = -1
	t.ok(not replica.accept(malformed, 4, "boss_colossus"), "shared snapshot rejects invalid exposure")
	t.equal(replica.target, packet, "invalid world cannot replace accepted snapshot")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("colossus-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual host capture is writable")
	if capture != null:
		capture.store_string(JSON.stringify(world))
		capture.close()
	for count in [2, 3, 4]: t.ok(View.valid(world, count), "actual JSON accepts bounded roster")
	for field in world.keys():
		var bad := world.duplicate(true)
		bad.erase(field)
		t.ok(not View.valid(bad, 4), "missing field rejected: " + field)
	for entry in [{"key": "exposed", "values": [-1, 2.41, true, NAN, INF, null]},
		{"key": "fist_scale", "values": [[0, 1, 1], [1.21, 1, 1], [NAN, 1, 1], [1, 1]]},
		{"key": "arm_rotation", "values": [[0, PI + 0.1, 0], [INF, 0, 0]]}]:
		for value in entry.values:
			var bad := world.duplicate(true)
			bad[entry.key] = value
			t.ok(not View.valid(bad, 4), "invalid pose or exposure rejected")
	var bad := world.duplicate(true)
	bad.craters[0].id = bad.warnings[0].id
	t.ok(not View.valid(bad, 4), "cross-type duplicate id rejected")
	for radius in [0.74, 100.1, NAN, true]:
		bad = world.duplicate(true)
		bad.craters[0].radius = radius
		t.ok(not View.valid(bad, 4), "invalid crater radius rejected")
	var view := View.new()
	guest.ctx.world_root.add_child(view)
	view.render(guest.controller, world, 0, false)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(guest.controller.presentation_only, "guest controller has presentation authority only")
	t.equal(guest.controller.boss_health, game.boss_health, "guest mirrors host damage")
	t.equal(guest.controller._fist.global_position, game._fist.global_position, "guest mirrors buried fist pose")
	t.equal(guest.controller._arm.rotation, game._arm.rotation, "guest mirrors arm rotation")
	t.ok(guest.arena._crater_floor._body == null, "guest carved floor has no collider")
	t.ok(not guest.arena.is_inside(Vector3(6, 0, 0)), "guest ground query matches real crater")
	t.equal(view.craters.size(), 1, "one presentation rim per host crater")
	t.equal(view.warnings.size(), 1, "one presentation warning per host warning")
	t.empty(guest.controller._craters, "guest has no simulated crater ownership")
	t.empty(guest.controller._telegraphs, "guest has no warning callbacks")
	var mesh: Mesh = guest.arena._crater_floor._mesh.mesh
	view.render(guest.controller, world, 0, true)
	t.equal(guest.arena._crater_floor._mesh.mesh, mesh, "repeated packet does not rebuild carved mesh")
	guest.controller._slam()
	guest.controller._sweep()
	guest.controller._open_crater(Vector3.ZERO, 4.0)
	guest.controller._check_arm_hits()
	guest.controller.boss_think(10.0)
	t.equal(guest.controller.boss_health, 745.0, "guest cannot decide damage")
	t.equal(guest.arena._crater_floor._mesh.mesh, mesh, "guest simulation cannot mutate host ground")
	t.empty(guest.controller._craters, "guest cannot spawn local crater")
	game.on_round_start()
	var reset: Dictionary = JSON.parse_string(JSON.stringify(View.capture(game)))
	t.ok(View.valid(reset, 4), "actual round reset snapshot remains valid")
	view.render(guest.controller, reset, 1, true)
	t.empty(view.craters, "round baseline retires crater views")
	t.empty(guest.arena._crater_floor.holes, "round baseline restores guest floor")
	t.equal(guest.controller.boss_health, 800.0, "round baseline restores host health")
	for scene in scenes:
		scene.teardown()
		scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
