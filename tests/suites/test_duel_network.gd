extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("duel network presentation")
	var cfg := MatchConfig.build("duel_pit", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game._lives.assign([0, 1, 2, 3])
	for slot in 4:
		scene.ctx.fighter(slot).damage_percent = float(slot) * 12.5
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "duel_pit"), "serialized duel accepted")
	for field in ["lives", "damage"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "duel_pit"), "missing field rejected")
	for life in [-1, 4, 0.5, NAN, INF, "1", true]:
		var bad := packet.duplicate(true)
		bad.world.lives[0] = life
		t.ok(not replica.accept(bad, 4, "duel_pit"), "invalid life rejected")
	for damage in [-1, 10001, NAN, INF, "1", true]:
		var bad := packet.duplicate(true)
		bad.world.damage[0] = damage
		t.ok(not replica.accept(bad, 4, "duel_pit"), "invalid damage rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "duel_pit"), "extra field rejected")
	bad = packet.duplicate(true)
	bad.world.damage.pop_back()
	t.ok(not replica.accept(bad, 4, "duel_pit"), "roster mismatch rejected")
	var scores: Array = Array(scene.ctx.scores).duplicate()
	game.on_round_start()
	for frame in 10:
		replica.render(scene, 0.016)
	for slot in 4:
		t.equal(game.lives(slot), int(packet.world.lives[slot]), "host lives restored")
		t.equal(scene.ctx.fighter(slot).damage_percent, float(packet.world.damage[slot]), "host damage restored")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot award points")
	t.ok(game._respawn_timers.is_empty(), "presentation cannot schedule respawns")
	t.ok(game.hud_value(2).contains("25%"), "HUD uses replicated damage")
	packet.world = {"lives": [3, 3, 3, 3], "damage": [0, 0, 0, 0]}
	packet.round = 1
	t.ok(replica.accept(packet, 4, "duel_pit"), "new round accepted")
	replica.render(scene, 0.016)
	for slot in 4:
		t.equal(game.lives(slot), 3, "new round restores all lives")
		t.equal(scene.ctx.fighter(slot).damage_percent, 0.0, "new round clears damage")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
