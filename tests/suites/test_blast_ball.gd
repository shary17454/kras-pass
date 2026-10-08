extends RefCounted

class ContactProbe extends GameBall:
	var checks := 0
	func _check_contacts() -> void:
		checks += 1


class ApproachProbe extends "res://src/ai/brains/ball_brain.gd":
	var observed := {}
	var observed_ball: GameBall
	var target := Vector3.INF
	var escaped := false
	var victim := -1
	var victim_position := Vector3.ZERO
	func _ball() -> GameBall:
		return observed_ball
	func perceive_ball(_ball: GameBall) -> Dictionary:
		return observed
	func _best_victim(_position: Vector3) -> int:
		return victim
	func perceive(_slot: int) -> Vector3:
		return victim_position
	func steer_to(point: Vector3, _urgency: float = 1.0) -> void:
		target = point
	func steer_away(_point: Vector3, _urgency: float = 1.0) -> void:
		escaped = true
	func maybe_dash(_scale: float = 1.0) -> void:
		pass
	func keep_off_edge(_threshold: float = 3.0) -> void:
		pass


class EscapeProbe extends "res://src/ai/brains/ball_brain.gd":
	var observed := {}
	var observed_ball: GameBall
	func _ball() -> GameBall:
		return observed_ball
	func perceive_ball(_ball: GameBall) -> Dictionary:
		return observed
	func maybe_dash(_scale: float = 1.0) -> void:
		pass


func run(t: TestHarness, host: Node) -> void:
	t.suite("blast ball lifecycle")
	var ball := GameBall.new()
	host.add_child(ball)
	ball.configure(Color.RED, 0.62, false, true)
	ball.fuse_max = 0.1
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	var events := [0]
	ball.exploded.connect(func(_ball, _position): events[0] += 1)
	ball.tick(0.2)
	ball.tick(0.2)
	t.equal(events[0], 1, "one explosion per launch even without a rearming listener")
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	t.equal(ball._label.text, "0.1", "launch immediately restores visible fuse")
	ball.tick(0.2)
	t.equal(events[0], 2, "rearmed ball can explode again")
	ball.queue_free()
	await host.get_tree().process_frame
	var probe := ContactProbe.new()
	host.add_child(probe)
	probe.explosive = true
	probe.fuse_max = 0.1
	probe.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	probe.exploded.connect(func(_ball, _position): probe.launch(Vector3(4, 0.9, 0), Vector3.FORWARD, 7))
	probe.tick(0.2)
	t.equal(probe.checks, 0, "rearming listener cannot apply stale overlap contacts to new ball")
	t.ok(not probe.detonated, "listener rearm clears detonation latch")
	probe.tick(0.01)
	t.equal(probe.checks, 1, "new launch checks contacts on its next tick")
	probe.queue_free()
	await host.get_tree().process_frame
	var cfg := MatchConfig.build("blast_ball", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 104)
	var capture_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-blast="):
			capture_path = arg.trim_prefix("--capture-blast=")
	if not capture_path.is_empty():
		cfg.players[0].is_human = true
		cfg.players[0].device_type = 2
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	_check_homing_ties(t, scene)
	var brain := ApproachProbe.new()
	brain.controller = game
	brain.configure(0, scene.ctx, 3, 733)
	brain.aggression = 1.0
	brain.risk = 1.0
	brain.reaction_time = 0.12
	brain.observed_ball = game.ball
	var trajectory := {"position": Vector3(2, 1, 0), "velocity": Vector3(8, 0, 0)}
	var anticipated := brain._anticipated_position(trajectory)
	t.ok(anticipated.x > 2.0, "planning uses observed ball motion rather than a stale position")
	game.ball.velocity = Vector3(-999, 0, 0)
	t.equal(brain._anticipated_position(trajectory), anticipated, "private ball momentum cannot change the visible trajectory estimate")
	brain.prediction = 0.0
	t.equal(brain._anticipated_position(trajectory), trajectory.position, "zero prediction uses only the delayed position")
	brain.prediction = 0.85
	t.equal(brain._anticipated_position({"position": Vector3(2, 1, 0)}), Vector3(2, 1, 0), "missing observed motion does not invent a velocity")
	var me: Fighter = scene.ctx.fighter(0)
	var original_position := me.global_position
	var original_speed := me.top_speed
	me.global_position = Vector3(0, 1.0, 0)
	me.top_speed = 5.0
	brain.observed = {"position": Vector3(8, 1.0, 0), "fuse": 1.8}
	game.ball.fuse = 999.0
	brain.decide(0.1)
	t.ok(brain.escaped, "distant short-fuse ball is not approached when travel consumes the remaining commit window")
	brain.escaped = false
	brain.target = Vector3.INF
	brain.observed["fuse"] = 5.0
	brain.decide(0.1)
	t.ok(brain.escaped, "full fuse still cannot fund distant contact plus the escape reserve")
	brain.escaped = false
	brain.observed["position"] = Vector3(4, 1.0, 0)
	brain.observed["radius"] = 0.62
	brain.decide(0.1)
	t.equal(brain.target, brain.observed["position"], "long visible fuse still permits an offensive approach")
	t.ok(not brain.escaped, "a viable approach is not replaced with unconditional retreat")
	brain.escaped = false
	brain.observed["position"] = Vector3(2.5, 1.0, 0)
	brain.observed["fuse"] = 1.8
	brain.decide(0.1)
	t.ok(brain.escaped, "close contact still needs time to leave the blast radius")
	brain.escaped = false
	var walk_speed := me.top_speed * float(me.mods["speed"]) * float(me.mutator["speed"])
	var escape_budget: float = lerp(2.4, 1.1, brain.risk * (1.0 - brain.strategy)) \
		+ brain.reaction_time + brain.decision_interval \
		+ Balance.num("tuning", "ball.explosive_radius", 5.0) / walk_speed
	brain.observed["radius"] = 0.62
	brain.observed["fuse"] = escape_budget + 0.05
	brain.decide(0.1)
	t.ok(brain.escaped, "being within attack range cannot remove the travel time required for ball contact")
	brain.escaped = false
	brain.observed["fuse"] = 5.0
	brain.decide(0.1)
	t.ok(not brain.escaped, "early close contact retains an offensive opportunity")
	brain.escaped = false
	brain.observed["age"] = 4.0
	brain.decide(0.1)
	t.ok(brain.escaped, "elapsed time since the visible fuse sample cannot fund a late approach")
	brain.observed.erase("age")
	brain.victim = 1
	brain.victim_position = Vector3(8, 1.0, 0)
	brain.observed = {"position": Vector3(2.5, 1.0, 0), "fuse": 5.0}
	me.global_position = Vector3(0, 1.0, 0)
	brain.decide(0.1)
	t.ok(brain.target.x < brain.observed["position"].x, "approach lines up behind the observed ball before contact")
	me.global_position = Vector3(1.1, 1.0, 0)
	brain.decide(0.1)
	t.ok(brain.target.x > brain.observed["position"].x, "aligned approach follows through the ball rather than stopping outside contact range")
	brain.victim = -1
	me.global_position = Vector3(0, 1.0, 0)
	brain.escaped = false
	me.top_speed = 1.0
	brain.decide(0.1)
	t.ok(brain.escaped, "slow movement cannot borrow the escape budget of a faster character")
	me.top_speed = 5.0
	var original_stun := me._stun
	var original_freeze: float = me.mods["frozen"]
	for status in ["frozen", "stunned"]:
		me.mods["frozen"] = 8.0 if status == "frozen" else 0.0
		me._stun = 8.0 if status == "stunned" else 0.0
		brain.escaped = false
		brain.target = Vector3.INF
		brain.decide(0.1)
		t.ok(brain.escaped, "own " + status + " duration cannot be spent as available approach time")
	var collision := me.get_node("Body") as CollisionShape3D
	var body_scale := collision.global_basis.get_scale().abs()
	var contact_radius: float = 0.62 + collision.shape.radius * maxf(body_scale.x, body_scale.z)
	var approach_budget := maxf(0.0, 2.5 - contact_radius) / walk_speed
	brain.observed["radius"] = 0.62
	brain.observed["fuse"] = escape_budget + approach_budget + 0.05
	me._stun = 0.0
	me.mods["frozen"] = 0.3
	brain.escaped = false
	brain.decide(0.1)
	t.ok(brain.escaped, "even a short freeze consumes a marginal approach budget")
	brain.observed["fuse"] = escape_budget + approach_budget + 0.25
	me._stun = 0.2
	me.mods["frozen"] = 0.2
	brain.escaped = false
	brain.decide(0.1)
	t.ok(not brain.escaped, "overlapping movement blocks expire concurrently, not consecutively")
	t.near(me._stun, 0.2, 0.00001, "planning cannot shorten the real stun timer")
	t.near(float(me.mods["frozen"]), 0.2, 0.00001, "planning cannot shorten the real freeze timer")
	brain.observed["fuse"] = 5.0
	me._stun = original_stun
	me.mods["frozen"] = original_freeze
	brain.escaped = false
	brain.decide(0.1)
	t.ok(not brain.escaped, "clear movement status preserves a viable offensive approach")
	brain.controller = null
	me.global_position = original_position
	me.top_speed = original_speed
	var escape := EscapeProbe.new()
	escape.controller = game
	escape.configure(0, scene.ctx, 3, 733)
	escape.edge_awareness = 1.0
	escape.observed_ball = game.ball
	var arena: Arena = scene.ctx.arena
	me.global_position = arena.global_position + Vector3.UP
	escape.prediction = 1.0
	escape.reaction_time = 0.12
	escape.decision_interval = 0.2
	escape.observed = {"position": me.global_position + Vector3.LEFT * 4.0,
		"velocity": Vector3.RIGHT * 18.0, "age": 0.13, "fuse": 0.2}
	escape.decide(0.1)
	t.ok(escape.move.x > 0.0, "escape does not run toward the incoming ball because its future forecast crosses the player")
	var estimated := escape._estimated_position_now(escape.observed)
	t.near(estimated.x - me.global_position.x, -1.66, 0.00001, "escape compensates only the elapsed visible-sample age")
	game.ball.velocity = Vector3.LEFT * 999.0
	t.equal(escape._estimated_position_now(escape.observed), estimated, "private live momentum cannot alter escape planning")
	escape.observed["age"] = 0.3
	escape.decide(0.1)
	t.ok(escape.move.x < 0.0, "a ball estimated to have already crossed changes the escape side")
	escape.prediction = 0.0
	t.equal(escape._estimated_position_now(escape.observed), escape.observed["position"], "zero prediction retains the delayed visible cue")
	escape.prediction = 1.0
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		me.global_position = arena.global_position + direction * (arena.current_radius - 0.2) + Vector3.UP
		escape.observed = {"position": arena.global_position + direction * (arena.current_radius - 2.5), "fuse": 0.2}
		escape.decide(0.1)
		var step := Vector3(escape.move.x, 0, escape.move.y)
		var tangent := Vector3(-direction.z, 0, direction.x)
		t.ok(absf(step.dot(tangent)) > 0.5, "escape follows the rim rather than steering back toward the observed bomb")
		t.ok(arena.is_inside(me.global_position + step, 0.15), "escape step remains on playable floor")
	escape.controller = null
	me.global_position = original_position
	var baseline := Balance.num("tuning", "ball.explosive_fuse", 5.0)
	game.on_sudden_death()
	game.ball.fuse = 0.2
	game.ball.last_toucher = 2
	game.ball._touch_cooldown[2] = 0.25
	game.ball.global_position = Vector3(3, 0.9, 2)
	var generation: int = game.ball.launch_generation
	game.on_round_start()
	t.near(game._fuse_max, baseline, 0.0001, "new round removes sudden death fuse override")
	t.near(game.ball.fuse, baseline, 0.0001, "new round has a complete fuse")
	t.equal(game.ball.last_toucher, -1, "new round has no previous attacker credit")
	t.ok(game.ball._touch_cooldown.is_empty(), "new round clears contact cooldowns")
	t.ok(game.ball.launch_generation > generation, "new round is a new launch generation")
	t.ok(game.ball.global_position.is_equal_approx(scene.arena.global_position + Vector3(0, 0.9, 0)), "new round returns ball to centre")
	for slot in scene.ctx.player_count():
		scene.ctx.alive[slot] = slot == 0
	scene.ctx.fighter(0).global_position = Vector3(0, 0.9, -100)
	var headings: Array[Vector3] = []
	for fps in [30, 60, 120]:
		game.ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
		for tick in fps / 2:
			game.ball.global_position = Vector3(0, 0.9, 0)
			game.tick(1.0 / fps)
		headings.append(game.ball.velocity.normalized())
	t.ok(headings[0].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 30 and 60 Hz")
	t.ok(headings[2].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 60 and 120 Hz")
	var adapter = load("res://src/net/blast_replica.gd").new()
	var world: Dictionary = JSON.parse_string(JSON.stringify(adapter.capture(game)))
	t.ok(adapter.valid(world), "blast world survives JSON")
	for field in world:
		var missing := world.duplicate(true)
		missing.erase(field)
		t.ok(not adapter.valid(missing), "blast world requires " + field)
	for field in ["position", "velocity", "explosion_position"]:
		for value in [null, [], [0, 0], [0, 0, 0, 0], [NAN, 0, 0], [true, 0, 0], [10001, 0, 0]]:
			var bad := world.duplicate(true)
			bad[field] = value
			t.ok(not adapter.valid(bad), "reject malformed blast vector")
	for field in ["generation", "explosion_sequence", "fuse", "fuse_max"]:
		for value in [null, true, "1", NAN, INF, -1, 1000001]:
			var bad := world.duplicate(true)
			bad[field] = value
			t.ok(not adapter.valid(bad), "reject malformed blast scalar")
	var scores := Array(scene.ctx.scores)
	var living: Variant = scene.ctx.alive.duplicate()
	world.explosion_sequence = 5
	world.fuse = 1.2
	world.position = [2, 0.9, 3]
	AudioManager._last_played.erase("explode")
	adapter.render(game, world, 0.1, true, true)
	t.ok(not AudioManager._last_played.has("explode"), "first snapshot does not play historical explosion")
	for repeat in 10:
		adapter.render(game, world, 1.0, false, true)
	t.near(game.ball.fuse, 1.2, 0.0001, "presentation never advances fuse")
	t.equal(game.ball._label.text, "1.2", "replica displays host fuse")
	t.equal(game.ball.collision_mask, 0, "replica cannot detect gameplay contacts")
	t.equal(Array(scene.ctx.scores), scores, "replica cannot score")
	t.equal(scene.ctx.alive, living, "replica cannot eliminate")
	world.explosion_sequence += 1
	adapter.render(game, world, 0.1, false, true)
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("explode"), "fresh explosion plays feedback")
	AudioManager._last_played.erase("explode")
	adapter.render(game, world, 0.1, false, true)
	t.ok(not AudioManager._last_played.has("explode"), "duplicate does not replay explosion")
	world.explosion_sequence += 1
	adapter.render(game, world, 0.1, true, false)
	adapter.render(game, world, 0.1, false, true)
	t.ok(not AudioManager._last_played.has("explode"), "suppressed reconnect event stays consumed")
	world.detonated = true
	world.fuse = 0
	t.ok(adapter.valid(world), "terminal detonation is valid")
	adapter.render(game, world, 0.1, false, true)
	t.ok(not game.ball.visible, "terminal detonated ball is hidden")
	world.detonated = false
	world.fuse = 2.0
	world.generation += 1
	world.position = [-2, 0.9, -3]
	adapter.render(game, world, 0.001, false, false)
	t.ok(game.ball.visible, "new launch restores visibility")
	t.ok(game.ball.global_position.is_equal_approx(Vector3(-2, 0.9, -3)), "new launch snaps without interpolating across arena")
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	packet.time = 30
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts blast world")
	var invalid := packet.duplicate(true)
	invalid.world.erase("fuse")
	t.ok(not replica.accept(invalid, 4, "blast_ball"), "shared match rejects incomplete blast world")
	t.equal(replica.target, packet, "invalid blast packet preserves last state")
	AudioManager._last_played.erase("explode")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "shared first snapshot is silent")
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts fresh explosion")
	replica.render(scene, 0.1)
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("explode"), "shared fresh explosion plays sound")
	AudioManager._last_played.erase("explode")
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts reconnect snapshot")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "shared reconnect skips historical explosion")
	packet.round += 1
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts next round")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "round transition does not replay explosion")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		packet.time = 42
		packet.round = 0
		packet.world.position = [0, 0.9, 0]
		packet.world.fuse = 2.8
		for slot in 4:
			packet.alive[slot] = true
			packet.fighters[slot].alive = true
			packet.fighters[slot].visible = true
			var spawn: Vector3 = scene.arena.global_position + scene.arena.spawn_points[slot]
			packet.fighters[slot].position = [spawn.x, spawn.y, spawn.z]
		t.ok(replica.accept(packet, 4, "blast_ball"), "accept visual fixture")
		replica.render(scene, 1.0)
		scene.camera._intro_left = 0
		await host.get_tree().create_timer(1.2).timeout
		if scene._pause_menu != null or scene._paused:
			scene._toggle_pause()
		await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
		t.ok(scene._pause_menu == null, "visual fixture is not obscured by pause menu")
		t.equal(scene.touch_sources.size(), 1, "visual fixture includes real touch controls")
		t.equal(host.get_viewport().get_texture().get_image().save_png(capture_path), OK, "save replicated blast fixture")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _check_homing_ties(t: TestHarness, scene: Node) -> void:
	var game = scene.controller
	var ctx: MatchContext = scene.ctx
	var positions: Array[Vector3] = []
	var living = ctx.alive.duplicate()
	var saved_state := ctx.rng.state
	var center: Vector3 = scene.arena.global_position + Vector3.UP
	var directions := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	for slot in 4:
		positions.append(ctx.fighter(slot).global_position)
		ctx.fighter(slot).global_position = center + directions[slot] * 4.0
		ctx.alive[slot] = slot != 2
	ctx.rng.seed = 82173
	var sequence: Array[int] = []
	var counts := [0, 0, 0, 0]
	for attempt in 256:
		var target: int = game._nearest_alive_to(center)
		sequence.append(target)
		counts[target] += 1
	t.equal(counts[2], 0, "dead equally near competitor is never selected")
	for slot in [0, 1, 3]:
		t.ok(counts[slot] > 40 and counts[slot] < 130, "equally near live competitors do not inherit slot-order priority")
	ctx.rng.seed = 82173
	for expected in sequence:
		t.equal(game._nearest_alive_to(center), expected, "tie selection repeats from the round seed")
	ctx.alive[2] = true
	ctx.fighter(2).global_position = center + Vector3.FORWARD
	var unique_state := ctx.rng.state
	t.equal(game._nearest_alive_to(center), 2, "a later unique nearest competitor replaces earlier tied candidates")
	t.equal(ctx.rng.state, unique_state, "unique nearest selection does not consume random state")
	for slot in 4:
		ctx.alive[slot] = false
	t.equal(game._nearest_alive_to(center), -1, "empty live set has no homing or blast victim")
	t.equal(ctx.rng.state, unique_state, "empty live set does not consume random state")
	for slot in 4:
		ctx.fighter(slot).global_position = positions[slot]
	ctx.alive = living
	ctx.rng.state = saved_state
