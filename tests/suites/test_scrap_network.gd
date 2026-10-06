extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("scrap network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var cfg := MatchConfig.build("scrap_karts", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for slot in 4:
		scene.ctx.fighter(slot).global_position = Vector3(30 + slot * 10, 1, 30)
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	a.global_position = Vector3(-1, 1, 0)
	b.global_position = Vector3(1, 1, 0)
	for velocities in [
		[Vector3(-10, 0, 0), Vector3(10, 0, 0)],
		[Vector3(0, 0, 10), Vector3(0, 0, -10)],
		[Vector3(0, 20, 0), Vector3.ZERO],
		[Vector3(3, 0, 15), Vector3.ZERO],
	]:
		a.velocity = velocities[0]
		b.velocity = velocities[1]
		game._resolve_rams()
		t.equal(game.ram_serial, 0, "separating, lateral, vertical and subthreshold closing cannot register a ram")
		t.equal(game.health[0], game._max_health, "nonclosing movement cannot injure first rider")
		t.equal(game.health[1], game._max_health, "nonclosing movement cannot injure second rider")
		t.ok(game._hit_cooldown.is_empty(), "noncontact cannot consume pair contact cooldown")
		game.on_round_start()
	for direction in [Vector3.RIGHT, Vector3.FORWARD]:
		a.global_position = -direction
		b.global_position = direction
		a.facing = direction
		b.facing = -direction
		a.velocity = direction * 10.0 + Vector3.UP * 70.0
		b.velocity = -direction * 10.0 - Vector3.UP * 70.0
		game._resolve_rams()
		t.equal(game.ram_serial, 1, "rotated real closing contact still registers one ram")
		var shared_damage: float = game._ram_damage * 20.0 / game._threshold * (0.6 + game._backwash) * 0.5
		t.near(game.health[0], game._max_health - shared_damage, 0.001, "equal head-on contact shares damage without vertical inflation")
		t.near(game.health[1], game.health[0], 0.001, "equal approach cannot choose an attacker by player slot")
		game.on_round_start()
	for pair in [[0, 1], [0, 3], [1, 2], [2, 3]]:
		for swap in [false, true]:
			for slot in 4:
				scene.ctx.fighter(slot).global_position = Vector3(30 + slot * 10, 1, 30)
			var first: Fighter = scene.ctx.fighter(pair[0])
			var second: Fighter = scene.ctx.fighter(pair[1])
			var direction := Vector3.RIGHT if not swap else Vector3.LEFT
			first.global_position = -direction
			second.global_position = direction
			first.facing = direction
			second.facing = -direction
			first.velocity = direction * 10.0
			second.velocity = -direction * 10.0
			game._resolve_rams()
			t.near(game.health[pair[0]], game.health[pair[1]], 0.001, "mirrored equal collision is independent of slots and world direction")
			game.on_round_start()
		for attacker in pair:
			for slot in 4:
				scene.ctx.fighter(slot).global_position = Vector3(30 + slot * 10, 1, 30)
			var victim: int = pair[1] if attacker == pair[0] else pair[0]
			var driver: Fighter = scene.ctx.fighter(attacker)
			var parked: Fighter = scene.ctx.fighter(victim)
			driver.global_position = Vector3.LEFT
			parked.global_position = Vector3.RIGHT
			driver.facing = Vector3.RIGHT
			parked.facing = Vector3.LEFT
			driver.velocity = Vector3.RIGHT * 10.0
			parked.velocity = Vector3.ZERO
			game._resolve_rams()
			var damage: float = game._ram_damage * 10.0 / game._threshold
			t.near(game.health[victim], game._max_health - damage * 0.6, 0.001, "unequal contact retains primary damage for the real victim")
			t.near(game.health[attacker], game._max_health - damage * game._backwash, 0.001, "unequal contact retains backwash regardless of attacker slot")
			game.on_round_start()
	for slot in 4:
		scene.ctx.fighter(slot).global_position = Vector3(30 + slot * 10, 1, 30)
	a.global_position = Vector3(-1, 1, 0)
	b.global_position = Vector3(1, 1, 0)
	a.velocity = Vector3(10, 0, 0)
	b.velocity = Vector3(-10, 0, 0)
	game._resolve_rams()
	t.equal(game.ram_serial, 1, "real closing-speed contact records one impact")
	t.ok(game.health[0] < game._max_health and game.health[1] < game._max_health, "real contact damages both riders")
	t.ok(game._hit_cooldown.has("0_1"), "real contact starts its pair cooldown")
	game._resolve_rams()
	t.equal(game.ram_serial, 1, "same contact cannot damage repeatedly during cooldown")
	game.on_round_start()
	t.ok(game._hit_cooldown.is_empty(), "new round cannot inherit contact immunity")
	t.equal(game.ram_serial, 0, "new round resets feedback generation")
	game._resolve_rams()
	t.equal(game.ram_serial, 1, "first contact of new round is not blocked by old cooldown")
	game._damage(2, 0, game._max_health, Vector3.FORWARD)
	t.equal(game.wrecks[2], 1, "real destruction records one wreck")
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "scrap_karts"), "serialized real ram and wreck state accepted")
	for key in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(key)
		t.ok(not replica.accept(bad, 4, "scrap_karts"), "missing world field rejected")
	for value in [-1, 100.01, NAN, INF, true, "1"]:
		var bad := packet.duplicate(true)
		bad.world.health[0] = value
		t.ok(not replica.accept(bad, 4, "scrap_karts"), "invalid health rejected")
	for value in [0, -1, 1001, NAN, INF, true, "1"]:
		var bad := packet.duplicate(true)
		bad.world.maximum = value
		t.ok(not replica.accept(bad, 4, "scrap_karts"), "invalid maximum rejected")
	for value in [-1, 0.5, 1000001, NAN, INF, true, "1"]:
		for field in ["ram", "wrecks"]:
			var bad := packet.duplicate(true)
			if field == "ram": bad.world.ram = value
			else: bad.world.wrecks[0] = value
			t.ok(not replica.accept(bad, 4, "scrap_karts"), "invalid feedback counter rejected")
	for field in ["health", "wrecks", "position"]:
		var bad := packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "scrap_karts"), "invalid field count rejected")
	for value in [10001, INF, NAN, true, "1"]:
		var bad := packet.duplicate(true)
		bad.world.position[0] = value
		t.ok(not replica.accept(bad, 4, "scrap_karts"), "invalid impact position rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "scrap_karts"), "extra field rejected")
	bad = packet.duplicate(true)
	bad.world.wrecks[0] = 1
	t.ok(not replica.accept(bad, 4, "scrap_karts"), "positive health cannot report a wreck")
	bad = packet.duplicate(true)
	bad.world.wrecks[2] = 2
	t.ok(not replica.accept(bad, 4, "scrap_karts"), "one-life rider cannot report multiple wrecks")
	for count in [1, 2, 3, 5]:
		t.ok(not replica.accept(packet, count, "scrap_karts"), "wrong roster rejected")
	var scores: Array = Array(scene.ctx.scores).duplicate()
	var alive: Array = Array(scene.ctx.alive).duplicate()
	game.on_round_start()
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	var voice: int = AudioManager._next_voice
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "baseline cannot replay old collisions or wrecks")
	for slot in 4:
		t.near(game.health[slot], packet.world.health[slot], 0.001, "host vehicle health restored")
	t.equal(game._bars[2].visible, false, "wrecked rider health label stays hidden")
	t.equal(game.hud_value(0), "%d%%" % int(round(packet.world.health[0])), "HUD uses host vehicle health")
	for frame in 10: replica.render(scene, 0.016)
	t.equal(Array(scene.ctx.scores), scores, "guest presentation does not award wreck points")
	t.equal(Array(scene.ctx.alive), alive, "guest presentation does not eliminate players")
	t.ok(game._hit_cooldown.is_empty(), "guest presentation does not resolve contacts")
	packet.world.ram += 1
	packet.world.wrecks[1] += 1
	packet.world.health[1] = 0
	packet.alive[1] = false
	packet.fighters[1].alive = false
	packet.fighters[1].visible = false
	AudioManager._last_played.erase("hit")
	AudioManager._last_played.erase("explode")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "scrap_karts"), "fresh feedback accepted")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, (voice + 2) % AudioManager.SFX_VOICES, "fresh impact and wreck each play once")
	voice = AudioManager._next_voice
	AudioManager._last_played.erase("hit")
	AudioManager._last_played.erase("explode")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate feedback stays silent without debounce")
	packet.world.ram += 1
	t.ok(replica.accept(packet, 4, "scrap_karts"), "stale feedback state accepted")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "stale reconnect feedback stays silent")
	packet.world.health = [100, 100, 100, 100]
	packet.world.ram = 0
	packet.world.wrecks = [0, 0, 0, 0]
	packet.alive = [true, true, true, true]
	for fighter in packet.fighters:
		fighter.alive = true
		fighter.visible = true
	packet.round += 1
	t.ok(replica.accept(packet, 4, "scrap_karts"), "new round accepted")
	replica.render(scene, 0.016)
	t.equal(game.ram_serial, 0, "new round feedback restored")
	t.equal(game.wrecks, [0, 0, 0, 0], "new round wreck counters restored")
	scene.teardown()
	scene.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame
