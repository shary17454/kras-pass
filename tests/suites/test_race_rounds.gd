extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("race round reset")
	var cfg := MatchConfig.build("kart_sprint", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for rider in scene.ctx.fighters: rider.set_physics_process(false)
	var game: Node = scene.controller
	var pad: Dictionary = game._boost_pads[0]
	var rider: Fighter = scene.ctx.fighter(0)
	rider.global_position = pad.pos + Vector3.UP
	game._check_boost(0, rider, 1.0 / 60.0)
	t.ok(pad.cooldown.has(0), "actual pad contact starts per-player recharge")
	t.near(pad.cooldown[0], 2.0, 0.001, "actual recharge retains its authored duration")
	t.ok(not game.boost_pad_positions(0).has(pad.pos), "recharging pad is not advertised as available")
	game.on_round_start()
	t.ok(pad.cooldown.is_empty(), "new round cannot inherit old pad cooldown")
	t.ok(game.boost_pad_positions(0).has(pad.pos), "new round restores pad availability")
	game._check_boost(0, rider, 1.0 / 60.0)
	t.ok(pad.cooldown.has(0), "first pad contact of next round is accepted")
	game.on_round_start()
	var original_context: int = cfg.context
	cfg.context = MatchConfig.Context.ONLINE
	cfg.players[0].is_human = true
	cfg.players[0].peer_id = 1
	cfg.players[1].peer_id = 2
	t.equal(cfg.human_slots(), [0], "local device roster excludes the remote human")
	t.equal(cfg.human_competitor_slots(), [0, 1], "race roster includes both local and remote humans")
	for slot in 4: scene.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 1, 100)
	_finish_checkpoints(game, scene.ctx.fighter(0))
	t.ok(game.finish_times[0] != game.UNFINISHED, "ordered checkpoint ticks finish the host's three laps")
	t.equal(game.lap[0], 3, "host finish retains the requested three laps")
	t.ok(not game.is_round_over(), "host finish cannot end a race while remote human is unfinished")
	_finish_checkpoints(game, scene.ctx.fighter(1))
	t.ok(game.finish_times[1] != game.UNFINISHED, "ordered checkpoint ticks finish the remote human")
	t.ok(game.is_round_over(), "all human competitors finishing can end the race")
	t.equal(game.finish_times[2], game.UNFINISHED, "unfinished bot does not block human completion")
	cfg.rules["online_contenders"] = [1, 2]
	cfg.rules["party_short_race"] = true
	cfg.rules["race_laps"] = 1
	game.on_round_start()
	for slot in 4: scene.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 1, 100)
	_finish_checkpoints(game, scene.ctx.fighter(0))
	t.ok(not game.is_round_over(), "noncontender finish cannot settle a race final")
	_finish_checkpoints(game, scene.ctx.fighter(1))
	t.ok(not game.is_round_over(), "human finalist still waits for the bot finalist")
	_finish_checkpoints(game, scene.ctx.fighter(2))
	t.ok(game.is_round_over(), "only authoritative finalists must finish the tiebreak")
	t.equal(game.finish_times[3], game.UNFINISHED, "unfinished spectator cannot block final completion")
	cfg.rules.erase("online_contenders")
	cfg.context = original_context
	t.equal(cfg.human_competitor_slots(), [0], "offline rules ignore stale remote peer metadata")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await _check_finished_collision(t, host)
	await _check_finished_weapons(t, host)
	await _check_weapon_character_response(t, host)


func _check_weapon_character_response(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "sakhra", "nabta", "barq"], 0, 1, 120)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for rider in scene.ctx.fighters: rider.set_physics_process(false)
	var game: Node = scene.controller
	var neutral: Fighter = scene.ctx.fighter(0)
	for slot in 4:
		var rider: Fighter = scene.ctx.fighter(slot)
		rider._stun = 0.0
		rider._impulse = Vector3.ZERO
		var health := rider.health
		game._spin_out(slot, (slot + 1) % 4, Vector3.RIGHT)
		t.near(rider._stun, game.SPIN_SECONDS * rider.data.perk_factor("recovery"), 0.00001, "race impact applies recovery for %s" % rider.data.id)
		var expected := (Vector3.RIGHT * 7.0 + Vector3.UP * 2.0) * neutral.knock_resist / rider.knock_resist
		t.ok(rider._impulse.is_equal_approx(expected), "race impulse applies character resistance for %s" % rider.data.id)
		t.near(rider.health, health, 0.00001, "race impact retains no health damage")
		t.equal(int(scene.ctx.details[slot].get("spun", 0)), 1, "race impact records one spin")
	t.ok(scene.ctx.fighter(1)._impulse.length() < neutral._impulse.length(), "heavy racer receives less knockback than neutral")
	t.ok(scene.ctx.fighter(3)._impulse.length() > neutral._impulse.length(), "light racer receives more knockback than neutral")
	t.near(neutral._stun, game.SPIN_SECONDS, 0.00001, "neutral race stun remains unchanged")
	t.ok(neutral._impulse.is_equal_approx(Vector3.RIGHT * 7.0 + Vector3.UP * 2.0), "neutral race impulse remains unchanged")
	var light: Fighter = scene.ctx.fighter(3)
	light._impulse = Vector3.ZERO
	light._stun = 0.0
	game.shielded[3] = 6.0
	game._spin_out(3, 0, Vector3.RIGHT)
	t.equal(light._impulse, Vector3.ZERO, "shield blocks all character-scaled knockback")
	t.near(light._stun, 0.0, 0.00001, "shield blocks character-scaled stun")
	t.near(game.shielded[3], 0.0, 0.00001, "shield is consumed once")
	var neutral_resist := neutral.knock_resist
	for character in Registry.characters():
		neutral.data = character
		neutral._apply_character()
		neutral._impulse = Vector3.ZERO
		neutral._stun = 0.0
		game._spin_out(0, 1, Vector3.RIGHT)
		var ratio := neutral_resist / neutral.knock_resist
		t.ok(neutral._impulse.is_equal_approx((Vector3.RIGHT * 7.0 + Vector3.UP * 2.0) * ratio), "%s uses effective resistance including its perk" % character.id)
		t.near(neutral._stun, game.SPIN_SECONDS * character.perk_factor("recovery"), 0.00001, "%s uses recovery without changing unrelated passives" % character.id)
		t.ok(ratio >= 0.85 and ratio <= 1.15, "%s race knockback stays within the effective response budget" % character.id)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _check_finished_weapons(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 119)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for rider in scene.ctx.fighters: rider.set_physics_process(false)
	var game: Node = scene.controller
	for slot in 4: scene.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 20, 100)
	var finished: Fighter = scene.ctx.fighter(0)
	_finish_checkpoints(game, finished)
	t.ok(game.finish_times[0] != game.UNFINISHED, "weapon fixture finishes through ordered race checkpoints")
	t.ok(game.rival_ahead(1) != 0, "missile targeting ignores the already finished leader")
	game.shielded[0] = 6.0
	var old_velocity: Vector3 = finished.velocity
	var old_hits: int = int(scene.ctx.details[1].get("hits", 0))
	game._spin_out(0, 1, Vector3.RIGHT)
	t.near(game.shielded[0], 6.0, 0.001, "completed racer cannot consume a shield on weapon contact")
	game.shielded[0] = 0.0
	game._spin_out(0, 1, Vector3.RIGHT)
	t.equal(finished.velocity, old_velocity, "completed racer cannot receive weapon knockback")
	t.equal(int(scene.ctx.details[1].get("hits", 0)), old_hits, "completed racer cannot grant weapon hit credit")
	game._drop_bomb(1, scene.ctx.fighter(1))
	var bomb: Dictionary = game._bombs.back()
	bomb.arm = 0.0
	finished.global_position = bomb.pos
	scene.ctx.fighter(1).global_position += Vector3.RIGHT * 20.0
	game._tick_bombs(0.01)
	t.equal(game._bombs.size(), 1, "completed racer cannot trigger an armed road bomb")
	scene.ctx.fighter(2).global_position = bomb.pos
	game._tick_bombs(0.01)
	t.equal(game._bombs.size(), 0, "unfinished racer still triggers the armed road bomb")
	t.ok(int(scene.ctx.details[2].get("spun", 0)) > 0, "road bomb still penalizes the unfinished racer")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _check_finished_collision(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("kart_sprint", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 118)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for rider in scene.ctx.fighters: rider.set_physics_process(false)
	var blocker: Fighter = scene.ctx.fighter(0)
	var racer: Fighter = scene.ctx.fighter(1)
	var layer: int = blocker.collision_layer
	var mask: int = blocker.collision_mask
	for slot in [2, 3]: scene.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 20, 100)
	racer.global_position = Vector3(0, 20, 0)
	blocker.global_position = Vector3(3, 20, 0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = racer.global_transform
	parameters.motion = Vector3(6, 0, 0)
	var contact := PhysicsTestMotionResult3D.new()
	t.ok(PhysicsServer3D.body_test_motion(racer.get_rid(), parameters, contact), "unfinished racer still has physical player collision")
	t.equal(contact.get_collider(), blocker, "real physics probe contacts the other racer")
	_finish_checkpoints(scene.controller, blocker)
	blocker.global_position = Vector3(3, 20, 0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not PhysicsServer3D.body_test_motion(racer.get_rid(), parameters), "finished kart cannot physically block an unfinished racer")
	t.equal(blocker.collision_mask & Fighter.LAYER_WORLD, mask & Fighter.LAYER_WORLD, "finished kart keeps world collision for floor support")
	scene.controller.on_round_start()
	t.equal(blocker.collision_layer, layer, "next round restores the original player collision layer")
	t.equal(blocker.collision_mask, mask, "next round restores the original collision mask")
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(PhysicsServer3D.body_test_motion(racer.get_rid(), parameters), "next round restores actual racer contact")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _finish_checkpoints(game: Node, rider: Fighter) -> void:
	# Rule-level fixture only, not physical-race or network qualification.
	for step in game.laps() * game._checkpoints.size() + 1:
		rider.global_position = game.next_checkpoint(rider.slot)
		game.tick(1.0 / 60.0)
