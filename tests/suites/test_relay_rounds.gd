extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("relay pickup and round lifecycle")
	var cfg := MatchConfig.build("crate_relay", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 113)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	t.ok(game.allows_attack(), "relay exposes functional attack controls")
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.carrying = 1
	fighter.can_attack = false
	game._update_carry_visuals()
	var mark: Node3D = game._carry_marks[0]
	var rejected: Collectible = game._items[0]
	# Match the deferred-disable ordering in Collectible.tick before its signal.
	rejected.available = false
	rejected.set_deferred("monitoring", false)
	game._on_taken(rejected, 0)
	await host.get_tree().process_frame
	t.ok(rejected.available and rejected.monitoring, "full carrier leaves crate collectible after deferred callbacks")
	t.equal(fighter.carrying, 1, "second pickup cannot stack cargo")
	var docks: Array = game._docks.duplicate(true)
	var scores := Array(scene.ctx.scores)
	game._spawn_timer = -9.0
	game._on_taken(game._items[1], 1)
	game.on_round_start()
	t.equal(game._items.size(), 4, "new round restores four center crates")
	t.near(game._spawn_timer, 2.2, 0.00001, "new round resets spawn timer")
	t.ok(game._carry_marks.is_empty(), "new round clears carried visuals")
	t.ok(not mark.visible and mark.is_queued_for_deletion(), "old cargo visual disappears immediately")
	t.equal(game._docks, docks, "round reset preserves docks without duplicates")
	t.equal(Array(scene.ctx.scores), scores, "reset does not award points")
	var identities := {}
	for item in game._items:
		t.ok(item.available, "fresh round crate is available")
		t.ok(not identities.has(item.get_instance_id()), "round pool contains no duplicate entry")
		identities[item.get_instance_id()] = true
	for slot in 4:
		t.equal(scene.ctx.fighter(slot).carrying, 0, "round clears carried cargo")
		t.equal(scene.ctx.fighter(slot).can_attack, game.allows_attack(), "round restores allowed attack")
	game._on_taken(game._items[0], 0)
	game._update_carry_visuals()
	fighter.global_position = game.base_position(0)
	game._check_deliveries()
	t.equal(scene.ctx.scores[0], 3, "new round can deliver cargo")
	game._check_deliveries()
	t.equal(scene.ctx.scores[0], 3, "delivery cannot be credited twice")
	game._on_taken(game._items[0], 0)
	t.equal(fighter.carrying, 1, "carrier has cargo before hit")
	EventBus.player_hit.emit(1, 0, 12.0)
	t.equal(fighter.carrying, 0, "ordinary hit spills cargo without a knockout")
	t.ok(fighter.alive and fighter.can_attack, "hit does not eliminate player or leave attack locked")
	var count: int = game._items.size()
	EventBus.player_hit.emit(1, 0, 12.0)
	t.equal(game._items.size(), count, "repeated hit cannot duplicate dropped cargo")
	game.cleanup()
	game.cleanup()
	t.ok(game._items.is_empty() and game._carry_marks.is_empty(), "cleanup releases items and carried visuals")
	t.ok(not EventBus.player_hit.is_connected(game._on_player_hit), "cleanup disconnects hit observer")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
