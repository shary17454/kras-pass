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
	t.test("high refresh presentation does not accelerate physics")
	t.equal(UserSettings.frame_limit_for_display(120, 120.0), 120, "120 Hz screens can request 120 frames")
	t.equal(UserSettings.frame_limit_for_display(120, 60.0), 60, "60 Hz screens are not forced to render 120 frames")
	t.equal(UserSettings.frame_limit_for_display(30, 120.0), 30, "explicit power-saving choice is retained")
	t.equal(UserSettings.frame_limit_for_display(0, -1.0), 120, "unknown refresh is bounded instead of unlimited")
	t.equal(Engine.physics_ticks_per_second, 60, "physics remains at its tested 60 Hz")
	await _every_minigame(t)
	await _multi_round(t)
	await _pause_and_restart(t)
	await _device_loss(t)
	await _difficulty_separation(t)
	await _rocket_rally_rules(t)
	await _ring_ordnance_rules(t)
	await _tank_battle_rules(t)
	await _fantasy_world_rules(t)
	await _race_lap_rules(t)
	await _race_recovery_rules(t)
	await _extended_races_finish(t)


func _fantasy_world_rules(t: TestHarness) -> void:
	t.test("fantasy circuits have continuous elevated driveable roads")
	for arena_id in Registry.minigame("sabaq_sawarikh").arena_ids:
		var arena := Arena.new()
		_host.add_child(arena)
		arena.build(Registry.arena(arena_id))
		await _host.get_tree().physics_frame
		t.ok(arena.get_node_or_null("FantasyWorld") != null, "world scenery exists")
		if arena.def.shape == "circuit":
			var world := arena.get_node("FantasyWorld")
			var structures := arena.get_node("RaceStructures")
			if arena_id == "dune_circuit":
				t.ok(structures.is_below_bridge(Vector3(73.92507, 1.918043, 30.31306)), "shallow bridge-bank trap also rescues racer")
			t.not_null(structures.get_node_or_null("TunnelCollision"), "tunnel has physical walls and ceiling")
			if arena_id == "magma_ring":
				t.not_null(structures.get_node_or_null("LavaUnderBridge"), "lava flows under bridge")
			var bridge_center: Vector3 = arena.circuit_line[26]
			t.ok(structures.is_below_bridge(bridge_center + Vector3.DOWN * 6), "bridge fall triggers rescue")
			t.ok(not structures.is_below_bridge(bridge_center + Vector3.UP), "bridge road remains safe")
			t.ok(world.get_node_or_null("WoodlandTerrain") != null, "natural world has sculpted terrain")
			if arena_id not in ["dune_circuit", "magma_ring", "alula_rain", "sinbad_coast"]:
				t.ok(world.get_node_or_null("River") != null, "river biome has water")
			if arena_id == "magma_ring":
				t.not_null(world.get_node_or_null("Lava"), "volcano has an animated lava crater")
				t.not_null(world.get_node_or_null("LavaFlow"), "volcano has lava flowing down its slope")
			if arena_id == "frost_hairpin":
				t.not_null(world.get_node_or_null("Weather/Snow"), "snow biome has snowfall")
			if arena_id == "alula_rain":
				t.equal(int(world.get_meta("biome")), 5, "AlUla has its own sandstone biome")
				t.ok(world.get_node("GravelRoad").material_override.get_shader_parameter("wet"), "AlUla asphalt is wet")
				var formations := world.get_node("SandstoneFormations")
				t.ok(formations.get_child_count() >= 20, "AlUla has scanned cliffs and matching collision")
				var cliff := formations.get_node("ScannedCliff4") as MeshInstance3D
				t.ok((cliff.transform * cliff.mesh.get_aabb()).size.y > 40.0, "AlUla has tall scanned sandstone mountains")
			if arena_id == "sinbad_coast":
				t.not_null(world.get_node_or_null("Ocean"), "Sinbad has a surrounding ocean")
				t.not_null(world.get_node_or_null("SinbadHarbour"), "Sinbad has its own harbour and sailing ships")
			if arena_id == "pharaoh_valley":
				t.not_null(world.get_node_or_null("PharaohMonuments"), "Pharaoh course has pyramids and a temple")
			if arena_id in ["neon_spiral", "alula_rain"]:
				t.not_null(world.get_node_or_null("Weather/Rain"), "storm biome has rain")
				var weather = world.get_node("Weather")
				var original_flashes = UserSettings.get_value("reduce_flashes")
				UserSettings._values["reduce_flashes"] = true
				weather.trigger_lightning()
				t.ok(not weather.bolt.visible, "lightning respects reduced flashes")
				UserSettings._values["reduce_flashes"] = false
				weather.trigger_lightning()
				t.ok(weather.bolt.visible, "storm has a visible lightning strike")
				weather._process(0.4)
				t.ok(not weather.bolt.visible, "lightning ends without leaving a bright sky")
				t.ok(absf(arena._light.light_energy - weather.base_energy) < 0.001, "light energy returns to normal")
				UserSettings._values["reduce_flashes"] = original_flashes
			t.ok(world.get_node_or_null("Guardrail") == null, "open course has no roadside fence")
			t.not_null(world.get_node_or_null("TerrainCollision"), "surrounding ground is driveable")
			for body in arena._static_root.get_children():
				t.ok(not body.has_meta("circuit_wall"), "no invisible track wall remains")
			for sample in range(120):
				var center := arena.circuit_line[sample]
				var forward := (arena.circuit_line[(sample + 1) % 120] - center).normalized()
				var across := Vector3(-forward.z, 0, forward.x).normalized()
				for side in [-1.0, 1.0]:
					var shoulder: Vector3 = center + across * side * (arena.track_width * 0.5 + 2.0)
					var cut: float = structures.excavation(arena, shoulder)
					var query := PhysicsRayQueryParameters3D.create(shoulder + Vector3.UP * 2, shoulder + Vector3.DOWN * 20, 1)
					var ground := arena.get_world_3d().direct_space_state.intersect_ray(query)
					t.ok(not ground.is_empty(), "both road shoulders have solid ground")
					var crossing_end := shoulder + Vector3.UP
					if not ground.is_empty():
						crossing_end.y = ground.position.y + 1.0
						if cut < 0.1:
							t.ok(absf(ground.position.y - center.y) < (arena.track_width * 0.5 + 2.0) * 0.55, "driveable shoulder slope %s sample %d" % [arena_id, sample])
						elif cut > 10.0 and ground.collider.name != "RoadCollision":
							t.ok(ground.position.y < center.y - 5.0, "bridge ground %s sample %d side %.0f collider %s" % [arena_id, sample, side, ground.collider.name])
					if cut > 0.1:
						continue
					var crossing := PhysicsRayQueryParameters3D.create(center + Vector3.UP, crossing_end, 1)
					t.ok(arena.get_world_3d().direct_space_state.intersect_ray(crossing).is_empty(), "open road edge %s sample %d side %.0f" % [arena_id, sample, side])
			t.equal(world._rock_meshes.size(), 6, "six scanned rock variations loaded")
			t.equal(world._tree_meshes.size(), 3, "three optimized pine variations loaded")
			var asphalt: ShaderMaterial = world.get_node("GravelRoad").material_override
			t.ok(asphalt.get_shader_parameter("surface_normal") != null, "road retains detailed surface normals")
			t.ok(arena.track_width >= 12.0, "asphalt road is wide enough for four racers")
			for mesh in world._tree_meshes:
				var triangle_count := 0
				for surface in mesh.get_surface_count():
					triangle_count += mesh.surface_get_array_index_len(surface) / 3
				t.ok(triangle_count < 15000, "each pine stays within its geometry budget")
		for index in range(0, 120, 10):
			var p := arena.track_point(float(index) / 120.0)
			t.ok(arena.is_inside(p), "elevation does not affect lateral track containment")
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2, p + Vector3.DOWN * 2, 1)
			var hit := arena.get_world_3d().direct_space_state.intersect_ray(ray)
			t.ok(not hit.is_empty(), "road has collision at every sampled hill")
			if not hit.is_empty():
				t.ok(absf(hit.position.y - p.y) < 0.3, "road visual and collision heights agree")
		var road_length := 0.0
		var low := INF
		var high := -INF
		for i in arena.circuit_line.size():
			road_length += arena.circuit_line[i].distance_to(arena.circuit_line[(i + 1) % arena.circuit_line.size()])
			low = minf(low, arena.circuit_line[i].y)
			high = maxf(high, arena.circuit_line[i].y)
		t.ok(road_length > 400.0, "authored route is at least twice the former short circuit")
		t.ok(high - low > 0.5, "route follows varied elevation")
		arena.queue_free()
		await _host.get_tree().process_frame


func _tank_battle_rules(t: TestHarness) -> void:
	t.test("tank battle armor, elimination, cover and round reset on all maps")
	for arena_id in Registry.minigame("tank_arena").arena_ids:
		var cfg := _make_config("tank_arena", PlayerConfig.Difficulty.EASY)
		cfg.arena_id = arena_id
		var scene: Node = load("res://src/match/match_scene.gd").new()
		_host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		var game = scene.controller
		t.equal(game.armor.size(), 4, "all four tanks have armor")
		var quad = scene.ctx.fighter(0)._visual.get_node_or_null("QuadBike")
		t.not_null(quad, "uses a four-wheel ATV, not an armored tank")
		if quad != null:
			t.equal(quad._wheels.size(), 4, "ATV has exactly four wheels")
			t.equal(quad._steering.size(), 2, "front wheels steer")
			quad.animate(0.1, 4.0, 1.0)
			t.ok(absf(quad._wheels[0].rotation.x) > 0.01, "quad tires rotate while driving")
			t.ok(absf(quad._steering[0].rotation.y) > 0.01, "front tires follow steering input")
		var shot := Projectile.new()
		scene.add_child(shot)
		await _host.get_tree().physics_frame
		t.equal(game.cover.size(), 16, "each battlefield has sixteen solid rock covers")
		t.not_null(game.world.get_node_or_null("TerrainCollision"), "natural terrain has physical collision")
		t.not_null(game.world.get_node_or_null("Pines0"), "battlefield uses the pine models")
		for cover in game.cover:
			t.ok(cover.get_child(0).mesh is ArrayMesh, "cover uses scanned geometry instead of primitive boxes")
		for id in game.world.roads.get_point_ids():
			var point: Vector3 = game.world.roads.get_point_position(id)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point + Vector3.DOWN, 1)
			var ground: Dictionary = scene.arena.get_world_3d().direct_space_state.intersect_ray(query)
			t.ok(not ground.is_empty(), "all trail intersections have driveable ground")
			if not ground.is_empty():
				t.ok(absf(ground.position.y) < 0.3, "navigation stays on the trail surface")
		t.ok(scene.arena.def.radius >= 46, "tank district is a full road map")
		t.ok(game.world.route(Vector3(-36, 0, -36), Vector3(36, 0, 36)).size() >= 9, "roads connect across the district")
		t.equal(scene.camera.mode, ArenaCamera.Mode.WORLD, "tank battle uses a follow camera")
		scene.camera.local_target = scene.ctx.fighter(0)
		t.ok(scene.camera._wanted_focus().is_equal_approx(scene.ctx.fighter(0).global_position), "camera follows the selected tank without centre bias")
		var barrier: StaticBody3D = game.cover[0]
		shot.fire(barrier.global_position + Vector3(0, 0, -7), Vector3.BACK, 0, 30, 25, 30)
		shot.tick(0.4)
		t.ok(not shot.active, "cover stops a shell swept through it")
		shot.damage = 25.0
		game._on_hit(shot, 0, 1)
		t.equal(game.armor[1], 75, "a shell removes 25 armor")
		t.ok(scene.ctx.is_alive(1), "survives the first hit")
		for i in 3:
			game._on_hit(shot, 0, 1)
		t.ok(not scene.ctx.is_alive(1), "four shells eliminate a tank")
		t.ok(game.compute_scores()[0] > game.compute_scores()[1], "survivor ranks above destroyed tank")
		game._on_hit(shot, 0, 1)
		t.equal(game.armor[1], 0, "duplicate hits cannot take armor below zero")
		for victim in [2, 3]:
			for i in 4:
				game._on_hit(shot, 0, victim)
		t.ok(game.is_round_over(), "last tank ends the round")
		game.on_round_start()
		t.equal(game.armor[1], 100, "next round restores armor")
		shot.free()
		scene.teardown()
		scene.queue_free()
		await _host.get_tree().process_frame


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
	while captured.is_empty() and elapsed < _match_window(cfg):
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
	if captured.is_empty() and cfg.minigame_id == "sabaq_sawarikh":
		print("RACE WATCHDOG ", scene.arena.def.id, " laps=", scene.controller.lap, " checkpoints=", scene.controller._next_cp)
		for driver in scene.ctx.fighters:
			print("driver ", driver.slot, " position=", driver.global_position, " alive=", driver.alive)
			print("target=", scene.controller.next_checkpoint(driver.slot), " velocity=", driver.velocity)
			for collision_index in driver.get_slide_collision_count():
				print("blocked by ", driver.get_slide_collision(collision_index).get_collider().name)
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
		t.ok(float(run_result["seconds"]) < _match_window(cfg), "%s finished before the test watchdog" % def.id)


func _match_window(cfg: MatchConfig) -> float:
	return 420.0 if cfg.minigame_id in ["kart_sprint", "sabaq_sawarikh"] else MAX_SECONDS_PER_MATCH


func _extended_races_finish(t: TestHarness) -> void:
	for arena_id in Registry.minigame("sabaq_sawarikh").arena_ids:
		t.test("three real AI laps finish on %s without a countdown" % arena_id)
		var cfg := _make_config("sabaq_sawarikh", PlayerConfig.Difficulty.MEDIUM)
		cfg.arena_id = arena_id
		var played := await _play(cfg)
		var result: MatchResult = played["result"]
		t.not_null(result, "all drivers can finish the authored route")
		if result != null:
			for score in result.scores:
				t.ok(score < 1000000, "driver finished rather than being ranked unfinished")
		t.equal(played["errors"], 0, "extended race logged no gameplay errors")


func _race_lap_rules(t: TestHarness) -> void:
	t.test("races end at the selected finish line, never on a countdown")
	var cfg := _make_config("sabaq_sawarikh", PlayerConfig.Difficulty.EASY, 1, 1)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	t.ok(not game.uses_round_clock(), "race has no time limit")
	for count in range(3, 11):
		cfg.rules["race_laps"] = count
		game.on_round_start()
		t.equal(game.laps(), count, "selected %d laps are used" % count)
		scene.phase = MatchPhase.P.PLAYING
		scene._phase_locked = false
		scene.ctx.time_left = 0.0
		scene._evaluate_end(0.1)
		t.equal(scene.phase, MatchPhase.P.PLAYING, "zero time does not end a race")
		var driver: Fighter = scene.ctx.fighter(0)
		driver.global_position = game._checkpoints[0]
		game.tick(0.02)
		t.equal(game.lap[0], 0, "initial start line crossing is not a completed lap")
		for completed in count:
			for checkpoint in range(1, game._checkpoints.size()):
				driver.global_position = game._checkpoints[checkpoint]
				game.tick(0.02)
			t.ok(not game.is_round_over(), "race stays live until the finish line")
			driver.global_position = game._checkpoints[0]
			game.tick(0.02)
			t.equal(game.lap[0], completed + 1, "lap counts at the finish line")
		t.ok(game.is_round_over(), "selected lap count finishes the human race")
		t.ok(game.compute_scores()[0] < game.compute_scores()[1], "finisher always ranks before unfinished rivals")
	cfg.rules["race_laps"] = 99
	t.equal(game.laps(), 10, "lap count is capped at ten")
	cfg.rules["race_laps"] = 1
	t.equal(game.laps(), 3, "lap count has a minimum of three")
	var replay := ReplayData.new()
	replay.rules = {"race_laps": 8}
	t.equal(replay.to_config().rule("race_laps", 3), 8, "replay configuration preserves lap count")
	scene.teardown()
	scene.queue_free()
	await _host.get_tree().process_frame


func _race_recovery_rules(t: TestHarness) -> void:
	t.test("race rescue costs time without granting checkpoint progress")
	var cfg := _make_config("sabaq_sawarikh", PlayerConfig.Difficulty.EASY, 1, 1)
	cfg.arena_id = "magma_ring"
	var scene: Node = load("res://src/match/match_scene.gd").new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	var f: Fighter = scene.ctx.fighter(0)
	var layer := f.collision_layer
	var mask := f.collision_mask
	game._started[0] = true
	game._next_cp[0] = 14
	f.global_position = scene.arena.circuit_line[26] + Vector3.DOWN * 6
	game.tick(0.02)
	t.ok(game.is_recovering(0), "fall below bridge starts rescue")
	t.ok(not f.control_enabled and not f.alive, "rescued racer cannot steer or collide")
	t.equal(f.collision_layer, 0, "rescue cannot hit opponents")
	game.process_respawns(1.0)
	game.on_fighter_fell(0)
	t.near(game._recoveries[0].time, 1.0, 0.001, "duplicate fall does not restart rescue")
	game.process_respawns(1.9)
	t.ok(game.is_recovering(0), "rescue lasts the full penalty")
	game.tick(0.02)
	t.equal(game._next_cp[0], 14, "rescue does not advance checkpoints")
	t.equal(game.lap[0], 0, "rescue does not award a lap")
	game.process_respawns(0.11)
	t.ok(not game.is_recovering(0), "rescue ends after three seconds")
	t.ok(f.alive and f.control_enabled and f.is_physics_processing(), "driver regains control")
	t.equal(f.collision_layer, layer, "collision layer restored")
	t.equal(f.collision_mask, mask, "collision mask restored")
	t.ok(f.global_position.distance_to(game._checkpoints[13] + Vector3.UP * 1.4) < 0.01, "return is to previous checkpoint")
	var heading: Vector3 = game._checkpoints[14] - game._checkpoints[13]
	heading.y = 0.0
	f._integrate_drive(Vector3.ZERO, 0.0)
	t.ok(f.facing.dot(heading.normalized()) > 0.999, "steering keeps the restored road heading on next physics tick")
	game.on_fighter_fell(0)
	game.on_round_end()
	t.ok(not game.is_recovering(0) and f.collision_mask == mask, "round end cleans rescue state")
	scene.teardown()
	scene.queue_free()
	await _host.get_tree().process_frame


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
		if scene.phase == MatchPhase.P.INSTRUCTIONS:
			InputRouter.frame(0).bits = 0
			scene._advance_timed_phase(20.0)
			t.equal(scene.phase, MatchPhase.P.INSTRUCTIONS, "instructions wait for human readiness")
			InputRouter.frame(0).bits = InputFrame.Btn.ATTACK
			InputRouter.frame(0).prev_bits = 0
			scene._advance_timed_phase(0.5)
			t.equal(scene.phase, MatchPhase.P.COUNTDOWN, "action starts the countdown")
			InputRouter.frame(0).clear()
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
		if driver != null and not game._boost_pads.is_empty():
			var pad: Dictionary = game._boost_pads[0]
			pad["cooldown"].clear()
			driver.global_position = pad["pos"]
			driver.facing = Vector3.FORWARD
			driver._impulse = Vector3.ZERO
			game._check_boost(0, driver, 0.02)
			t.ok(driver._impulse.length() > 10.0, "green pad accelerates the vehicle")
			var impulse := driver._impulse
			game._check_boost(0, driver, 0.02)
			t.equal(driver._impulse, impulse, "pad cooldown prevents repeated acceleration every frame")
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
