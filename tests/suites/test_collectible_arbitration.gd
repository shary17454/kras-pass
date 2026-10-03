extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("collectible arbitration")
	var item := Collectible.new()
	host.add_child(item)
	item.global_position = Vector3(100, 1, -50)
	var players: Array[Fighter] = []
	for slot in 4:
		var player := Fighter.new()
		player.slot = slot
		host.add_child(player)
		players.append(player)
		player.global_position = item.global_position + Vector3(0.6, 0, 0)
	players[1].global_position = item.global_position + Vector3(0.1, 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7349
	var previous := rng.state
	t.test("closest collector does not depend on overlap insertion order")
	t.equal(item._select_collector([players[0], players[1]], rng), players[1], "nearer second body wins")
	t.equal(item._select_collector([players[1], players[0]], rng), players[1], "reversed body list has the same closest collector")
	t.equal(rng.state, previous, "unique nearest body consumes no tie randomness")
	t.test("game eligibility is evaluated before overlap arbitration")
	players[1].carrying = 1
	var eligible := func(body: Fighter) -> bool: return body.carrying == 0
	t.equal(item._select_collector([players[1], players[0]], rng, eligible), players[0], "full cargo carrier cannot starve a waiting collector")
	players[0].carrying = 1
	t.equal(item._select_collector([players[0], players[1]], rng, eligible), null, "no eligible collector leaves the item available")
	t.test("dead bodies and dropped-loot grace remain excluded")
	players[1].alive = false
	t.equal(item._select_collector([players[1], players[0]], rng), players[0], "dead nearest body is ignored")
	players[0].alive = false
	t.equal(item._select_collector([players[0], players[1]], rng), null, "all dead bodies cannot take the item")
	players[0].alive = true
	item.owner_slot = 0
	item._grace = 0.7
	t.equal(item._select_collector([players[0], players[2]], rng), players[2], "dropper's grace cannot deny another collector")
	item._grace = 0.0
	players[1].alive = true
	for player in players:
		player.carrying = 0
		player.global_position = item.global_position + Vector3(0.5, 0, 0)
	t.test("seeded exact ties are reproducible independent of body order")
	var replay := RandomNumberGenerator.new()
	rng.seed = 9362
	replay.seed = rng.seed
	var counts := [0, 0, 0, 0]
	for sample in 800:
		var winner: Fighter = item._select_collector(players, rng)
		var reverse: Fighter = item._select_collector([players[3], players[2], players[1], players[0]], replay)
		t.equal(winner.slot, reverse.slot, "same seed chooses the same tied player despite overlap order")
		counts[winner.slot] += 1
	for slot in 4:
		t.ok(counts[slot] >= 140 and counts[slot] <= 260, "fixed-seed fixture gives every tied player opportunities")
	t.equal(item._select_collector([], rng), null, "empty overlap has no collector")
	for node in players + [item]:
		node.queue_free()
	await host.get_tree().process_frame
	await _crate_capacity(t, host)


func _crate_capacity(t: TestHarness, host: Node) -> void:
	t.test("real relay overlap does not emit rejected pickups every tick")
	var cfg := MatchConfig.build("crate_relay", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 991)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var crate: Collectible = game._items[0]
	var at := crate.global_position
	var taken: Array[int] = []
	crate.taken.connect(func(_item: Collectible, slot: int): taken.append(slot))
	for slot in 4:
		var body: Fighter = scene.ctx.fighter(slot)
		body.carrying = 1
		body.global_position = at + Vector3(0.1 * slot, -0.6, 0) if slot < 2 else at + Vector3(100, 0, slot * 5)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.at_least(crate.get_overlapping_bodies().size(), 2, "fixture has genuine simultaneous physical overlap")
	game.tick(1.0 / 60.0)
	t.equal(taken.size(), 0, "full carriers do not emit and reject a pickup")
	t.ok(crate.available, "crate remains available for an eligible carrier")
	scene.ctx.fighter(1).carrying = 0
	game.tick(1.0 / 60.0)
	t.equal(taken, [1], "waiting eligible player takes the crate despite a closer full carrier")
	t.equal(scene.ctx.fighter(1).carrying, 1, "eligible player receives exactly one cargo")
	t.ok(not crate.available and not game._items.has(crate), "successful pickup retires the crate once")
	game.tick(1.0 / 60.0)
	t.equal(taken, [1], "later ticks cannot duplicate the same pickup")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
