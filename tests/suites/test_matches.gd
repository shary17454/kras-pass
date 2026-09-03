extends RefCounted
## Integration: play every mini-game to completion, headless, with four AI
## competitors, and assert the whole match pipeline behaves.
##
## This is the test that makes "all implemented games are finishable" a fact
## rather than a claim. It also covers the QA scenarios that are hard to check
## by hand every build: pause, restart, early quit, controller loss and the
## multi-round path.

# 110 not 70: with impulse physics fixed, nobody gets thrown out of a ring in
# a 5-second round any more, so short test rounds legitimately reach sudden
# death and need the extra simulated seconds to resolve.
const MAX_SECONDS_PER_MATCH := 110.0
const ROUND_SECONDS := 5.0

var _host: Node


func run(t: TestHarness, host: Node) -> void:
	_host = host
	t.suite("matches (integration)")
	await _every_minigame(t)
	await _multi_round(t)
	await _pause_and_restart(t)
	await _device_loss(t)
	await _difficulty_separation(t)
	await _rocket_rally_rules(t)
	await _ring_ordnance_rules(t)


func _characters() -> Array:
	var all := Registry.characters()
	var out: Array = []
	for i in 4:
		out.append(all[i % all.size()].id)
	return out


func _make_config(game_id: String, difficulty: int, rounds: int = 1, humans: int = 0) -> MatchConfig:
	var cfg := MatchConfig.build(game_id, _characters(), humans, difficulty, 1234)
	cfg.rounds = rounds
	cfg.duration_override = ROUND_SECONDS
	cfg.allow_powerups = true
	return cfg


## Runs one match to completion and returns {result, scene, errors, moved}.
func _play(cfg: MatchConfig) -> Dictionary:
	var errors_before := Log.error_count()
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	var captured: Array = []
	scene.setup({"config": cfg, "on_finished": func(r): captured.append(r)})

	var start_positions: Array = []
	var moved := false
	var elapsed := 0.0
	var max_focus_offset := 0.0
	var tree := _host.get_tree()
	while captured.is_empty() and elapsed < MAX_SECONDS_PER_MATCH:
		await tree.physics_frame
		elapsed += 1.0 / 60.0
		# Track how far the camera's subject drifts from the arena. A camera
		# that follows a knocked-off player over the edge takes the remaining
		# action off screen — see the note in ArenaCamera._live_targets().
		if scene.camera != null and scene.arena != null and MatchPhase.is_live(scene.phase):
			var f: Vector3 = scene.camera.focus - scene.arena.global_position
			max_focus_offset = maxf(max_focus_offset, Vector2(f.x, f.z).length())
		if scene.ctx != null and start_positions.is_empty() and MatchPhase.is_live(scene.phase):
			for f in scene.ctx.fighters:
				start_positions.append(f.global_position)
		elif not moved and start_positions.size() > 0 and scene.ctx != null:
			for i in scene.ctx.fighters.size():
				if scene.ctx.fighters[i].global_position.distance_to(start_positions[i]) > 1.0:
					moved = true
					break
	var out := {
		"result": captured[0] if captured.size() > 0 else null,
		"phase": scene.phase,
		"errors": Log.error_count() - errors_before,
		"moved": moved,
		"seconds": elapsed,
		"max_focus_offset": max_focus_offset,
		"arena_radius": scene.arena.def.radius if scene.arena != null else 0.0,
		"camera_mode": scene.camera.mode if scene.camera != null else -1,
	}
	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	return out


func _every_minigame(t: TestHarness) -> void:
	# all_minigames(), not minigames(): the boss fights are excluded from the
	# player-facing rotation but they are still real matches, and "every game
	# finishes, ranks everyone and moves its bots" has to hold for them too.
	for def in Registry.all_minigames():
		t.test("play %s to completion" % def.id)
		var cfg := _make_config(def.id, PlayerConfig.Difficulty.MEDIUM)
		var run_result := await _play(cfg)
		var result: MatchResult = run_result["result"]
		t.not_null(result, "%s produced a result" % def.id)
		if result == null:
			continue
		t.equal(int(run_result["errors"]), 0, "%s logged no errors" % def.id)
		t.equal(result.places.size(), cfg.player_count(), "%s ranked every competitor" % def.id)
		t.equal(result.scores.size(), cfg.player_count(), "%s scored every competitor" % def.id)
		t.at_least(result.winners().size(), 1, "%s produced at least one winner" % def.id)
		var seen_places := {}
		for p in result.places:
			t.ok(p >= 1 and p <= cfg.player_count(), "%s place %d is in range" % [def.id, p])
			seen_places[p] = true
		t.ok(seen_places.has(1), "%s awarded a first place" % def.id)
		t.ok(bool(run_result["moved"]), "%s: AI competitors actually moved" % def.id)
		if int(run_result["camera_mode"]) != ArenaCamera.Mode.RACE:
			t.ok(float(run_result["max_focus_offset"]) <= float(run_result["arena_radius"]),
				"%s: the camera never leaves the arena chasing a falling player" % def.id)
		t.ok(float(run_result["seconds"]) < MAX_SECONDS_PER_MATCH, "%s finished before the timeout" % def.id)


func _multi_round(t: TestHarness) -> void:
	t.test("three-round match aggregates correctly")
	var cfg := _make_config("ring_rumble", PlayerConfig.Difficulty.EASY, 3)
	var run_result := await _play(cfg)
	var result: MatchResult = run_result["result"]
	t.not_null(result, "multi-round match completed")
	if result == null:
		return
	t.equal(result.rounds.size(), 3, "three rounds were played")
	var total := 0
	for r in result.rounds:
		total += r.score_of(0)
	t.equal(result.score_of(0), total, "match score is the sum of round scores")
	t.equal(int(run_result["errors"]), 0, "no errors across rounds")


func _pause_and_restart(t: TestHarness) -> void:
	t.test("pause halts the clock, restart replays the round, quit is clean")
	var cfg := _make_config("crate_smash", PlayerConfig.Difficulty.EASY)
	cfg.duration_override = 30.0
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	var tree := _host.get_tree()
	var wait := 0
	while not MatchPhase.is_live(scene.phase) and wait < 3000:
		await tree.physics_frame
		wait += 1
	t.ok(MatchPhase.is_live(scene.phase), "the match reached a live phase")

	scene._toggle_pause()
	var frozen: float = scene.ctx.time_left
	for i in 20:
		await tree.physics_frame
	t.near(scene.ctx.time_left, frozen, 0.001, "the clock does not run while paused")
	scene._toggle_pause()
	for i in 20:
		await tree.physics_frame
	t.ok(scene.ctx.time_left < frozen, "the clock resumes")

	scene.debug_add_score(0, 5)
	t.equal(scene.ctx.scores[0], 5, "debug scoring works")
	scene.debug_restart_round()
	for i in 5:
		await tree.physics_frame
	t.equal(scene.ctx.scores[0], 0, "restart clears the round score")
	t.ok(scene.ctx.alive_count() == cfg.player_count(), "restart revives everyone")

	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	t.ok(true, "teardown after an abandoned match does not crash")


func _device_loss(t: TestHarness) -> void:
	t.test("losing a controller pauses instead of stranding the player")
	var cfg := _make_config("ring_rumble", PlayerConfig.Difficulty.EASY, 1, 1)
	cfg.duration_override = 30.0
	cfg.players[0].device_type = 1
	cfg.players[0].device_id = 7   # a pad that is not connected
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	var tree := _host.get_tree()
	var guard := 0
	while not MatchPhase.is_live(scene.phase) and guard < 2000:
		await tree.physics_frame
		guard += 1
	EventBus.player_device_lost.emit(0)
	await tree.physics_frame
	t.ok(scene._paused, "the match pauses when a human's device disappears")
	scene.teardown()
	scene.queue_free()
	await tree.process_frame


## Expert opponents should out-score Easy ones. Measured on the point-scoring
## games, where skill maps directly to the scoreboard — in an elimination game
## the aggressive high tiers also knock *each other* out, so it is a poor
## instrument for this. The point is to catch a difficulty curve that has been
## wired up backwards or flattened to nothing, so the bar is total points across
## several seeds rather than any single round.
func _difficulty_separation(t: TestHarness) -> void:
	# Controlled comparison: all four competitors play the *same* character, so
	# the only variable is skill. (An earlier version of this test let the slots
	# keep their default characters and measured Sakhra's low top speed instead
	# of the AI tier.) Each seed is also run mirrored, with the expert pair on
	# the opposite slots, to cancel any spawn-position advantage.
	var same := ["fanoos", "fanoos", "fanoos", "fanoos"]
	for game in ["gem_grab", "crate_smash"]:
		t.test("expert AI out-scores easy AI in %s" % game)
		var expert_total := 0
		var easy_total := 0
		for i in 4:
			var expert_first := i % 2 == 0
			var cfg := MatchConfig.build(game, same, 0, PlayerConfig.Difficulty.EASY, 100 + i * 37)
			cfg.duration_override = 12.0
			cfg.rounds = 1
			cfg.allow_powerups = false   # remove the biggest source of variance
			for slot in 4:
				var is_expert := (slot < 2) == expert_first
				cfg.players[slot].ai_difficulty = PlayerConfig.Difficulty.EXPERT if is_expert \
					else PlayerConfig.Difficulty.EASY
			var run_result := await _play(cfg)
			var result: MatchResult = run_result["result"]
			if result == null:
				continue
			for slot in 4:
				var is_expert := (slot < 2) == expert_first
				if is_expert:
					expert_total += result.score_of(slot)
				else:
					easy_total += result.score_of(slot)
		t.greater(expert_total, easy_total,
			"%s: expert competitors out-score easy ones across four mirrored seeds" % game)


## Three rules of Rocket Rally that a "the match completed" test cannot see.
## Every one of them shipped through a green suite and was caught in review.
func _rocket_rally_rules(t: TestHarness) -> void:
	t.test("Rocket Rally: crossing the line ends your involvement")
	var cfg := _make_config("sabaq_sawarikh", PlayerConfig.Difficulty.EASY)
	cfg.duration_override = 40.0
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	var tree := _host.get_tree()
	var wait := 0
	while not MatchPhase.is_live(scene.phase) and wait < 3000:
		await tree.physics_frame
		wait += 1
	t.ok(MatchPhase.is_live(scene.phase), "the race reached a live phase")

	var game = scene.controller
	t.not_null(game, "the race controller exists")
	if game != null:
		# Boost pads are inherited from Kart Sprint, which used to place them on
		# a circle derived from the arena radius. That is only the racing line on
		# an oval; on a lobed circuit it put them behind the inner wall, where no
		# kart could reach them and the racing brain still steered at them.
		var arena := scene.arena as Arena
		var half: float = arena.track_width * 0.5
		for pad in game.boost_pad_positions(0):
			var p: Vector3 = pad
			var nearest := INF
			for k in 240:
				nearest = minf(nearest, Vector3(p.x, 0.0, p.z).distance_to(
					arena.track_point(float(k) / 240.0)))
			t.ok(nearest < half, "boost pad sits on the road (%.2fm from the line, half-width %.2f)"
				% [nearest, half])

		# A finished racer keeps `is_alive`; Kart Sprint only clears
		# `control_enabled`. Driven through the crate path rather than the fire
		# button, because a headless AI never presses attack — a test that waits
		# for input here passes whether the guard exists or not.
		var driver: Fighter = scene.ctx.fighter(0)
		if driver != null and is_instance_valid(driver) and not game._crates.is_empty():
			var crate: Dictionary = game._crates[0]
			crate["cooldown"] = 0.0
			game.held[0] = game.Item.NONE
			game.finish_times[0] = 1
			driver.global_position = crate["pos"]
			game._tick_crates(0.02)
			t.equal(game.held[0], game.Item.NONE, "a finished racer cannot take a crate")
			game.finish_times[0] = game.UNFINISHED
			game._tick_crates(0.02)
			t.ok(game.held[0] != game.Item.NONE, "and an unfinished one still can")
			game.held[0] = game.Item.NONE

		# `Projectile` applies its own knockback, stun and hitstop *before* it
		# emits `hit_fighter`, so a shield checked in the callback was consumed
		# after the hit had landed rather than instead of it. Asserting on the
		# fired shot, not on `_spin_out`: `_spin_out` always honoured the shield,
		# the bug was everything that ran before it got the chance.
		var shooter: Fighter = scene.ctx.fighter(0)
		if shooter != null and is_instance_valid(shooter):
			game._launch_missile(0, shooter)
			t.ok(not game._missiles.is_empty(), "the rocket is airborne")
			if not game._missiles.is_empty():
				var shot: Projectile = game._missiles[game._missiles.size() - 1]
				t.ok(shot.notify_only,
					"the rocket reports its hit instead of applying one, so the shield can stop it")

		var victim: Fighter = scene.ctx.fighter(1)
		if victim != null and is_instance_valid(victim):
			game.shielded[1] = 5.0
			victim._stun = 0.0
			game._spin_out(1, 0, Vector3.FORWARD)
			t.near(victim._stun, 0.0, 0.001, "a shielded racer is not spun out")
			t.near(game.shielded[1], 0.0, 0.001, "and the shield is spent doing it")
			game._spin_out(1, 0, Vector3.FORWARD)
			t.ok(victim._stun > 0.0, "the next hit lands once the shield is gone")

	scene.queue_free()
	await tree.process_frame


func _ring_ordnance_rules(t: TestHarness) -> void:
	t.test("Ring Rumble: arctic bombs dismount before the next hit lands")
	var cfg := _make_config("ring_rumble", PlayerConfig.Difficulty.EASY)
	cfg.duration_override = 30.0
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	var tree := _host.get_tree()
	var wait := 0
	while not MatchPhase.is_live(scene.phase) and wait < 3000:
		await tree.physics_frame
		wait += 1
	t.ok(MatchPhase.is_live(scene.phase), "the ring reached a live phase")

	var game = scene.controller
	var victim: Fighter = scene.ctx.fighter(1)
	t.not_null(game, "the ring controller exists")
	t.not_null(victim, "a victim exists")
	if game != null and victim != null and is_instance_valid(victim):
		t.ok(victim.has_mount(), "arctic fighters start mounted")
		game._drop_ordnance()
		t.ok(not game._ordnance.is_empty(), "the ring dropped an ordnance pickup")
		var b: Dictionary = game._ordnance[0]
		var node: Node3D = b["node"]
		node.global_position = victim.global_position
		game._try_take_ordnance(b, node)
		t.equal(victim.carrying, game.ORDNANCE_CARRY_FLAG, "walking over a drop arms a carried bomb")
		b["held"] = -1
		victim.carrying = 0
		b["thrower"] = 0
		b["kind"] = game.BombKind.FIRE
		node.global_position = victim.global_position
		game._detonate_ordnance(0)
		t.ok(not victim.has_mount(), "the first bomb throws the mount away")
		victim._invuln = 0.0
		var damage_before := victim.damage_percent
		game._drop_ordnance()
		b = game._ordnance[0]
		node = b["node"]
		b["thrower"] = 0
		b["kind"] = game.BombKind.FIRE
		node.global_position = victim.global_position
		game._detonate_ordnance(0)
		t.greater(victim.damage_percent, damage_before, "the next bomb burns or launches the unmounted fighter")

	scene.teardown()
	scene.queue_free()
	await tree.process_frame
