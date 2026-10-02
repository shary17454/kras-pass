extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Hurdle = preload("res://src/net/hurdle_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("hurdle network presentation")
	var cfg := MatchConfig.build("hurdle_dash", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game._elapsed = 12.5
	game.finish_times.assign([1000, 1200, 1250, game.UNFINISHED])
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "hurdle_dash"), "serialized hurdle state accepted")
	for field in ["elapsed", "times"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "hurdle_dash"), "missing field rejected")
	for elapsed in [-1, 3601, NAN, INF, "12.5", true]:
		var bad := packet.duplicate(true)
		bad.world.elapsed = elapsed
		t.ok(not replica.accept(bad, 4, "hurdle_dash"), "invalid elapsed rejected")
	for time in [-1, 1251, 0.5, 360001, NAN, INF, "1000", true]:
		var bad := packet.duplicate(true)
		bad.world.times[0] = time
		t.ok(not replica.accept(bad, 4, "hurdle_dash"), "invalid finish rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "hurdle_dash"), "unknown fields rejected")
	bad = packet.duplicate(true)
	bad.world.times.pop_back()
	t.ok(not replica.accept(bad, 4, "hurdle_dash"), "roster mismatch rejected")
	var scores: Array = Array(scene.ctx.scores)
	game.on_round_start()
	replica.render(scene, 0.016)
	for slot in 4:
		t.equal(game.finish_times[slot], int(packet.world.times[slot]), "host finish times restored")
	t.equal(game._finished, 3, "finished count derived from host times")
	t.equal(game.hud_banner(), "12.50", "guest HUD clock matches host")
	t.equal(game.hud_value(1), "12.00", "guest HUD finish matches host")
	for fighter in scene.ctx.fighters:
		t.ok(not fighter.control_enabled, "guest rendering cannot enable local physics input")
	t.equal(Array(scene.ctx.scores), scores, "presentation never awards points")
	packet.world.times.fill(game.UNFINISHED)
	packet.world.elapsed = 0.0
	packet.round = 1
	t.ok(replica.accept(packet, 4, "hurdle_dash"), "new round accepted")
	replica.render(scene, 0.016)
	t.equal(game._finished, 0, "new round clears finish count")
	t.equal(game.hud_banner(), "0.00", "new round clears elapsed HUD")
	t.equal(replica._hurdle.last_round, 1, "event baseline follows round")
	t.equal(replica._hurdle.last_times, packet.world.times, "event baseline clears old finishes")
	t.ok(Hurdle.valid({"elapsed": 3600, "times": [360000, 99999]}, 2), "maximum bounded elapsed accepted")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
