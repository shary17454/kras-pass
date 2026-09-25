extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("local party core")
	_tournaments(t)
	_saves(t)
	_settings(t)
	_profiles(t)
	_characters(t)
	_touch_geometry(t)
	await _touch_players(t, host)
	await _weapons(t, host)
	await _tank_variants_and_pause(t, host)
	await _shared_cameras(t, host)
	await _collector_decisions(t, host)
	_validator(t)


func _players() -> Array[PlayerConfig]:
	return MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 21).players


func _session(count := 3) -> TournamentSession:
	var games: Array[String] = []
	for i in count:
		games.append("ring_rumble")
	var session := TournamentSession.new()
	session.setup(_players(), games, 912)
	return session


func _tournaments(t: TestHarness) -> void:
	t.test("one short cup, one optional double final, no duplicate rewards")
	var s := _session()
	s.double_final = true
	var result := MatchResult.make("ring_rumble", "vortex_ring", [8, 6, 4, 2] as Array[int])
	s.record(result)
	t.equal(s.points, [5, 3, 2, 1], "first round has ordinary points")
	s.record(result)
	s.record(result)
	t.equal(s.points, [20, 12, 8, 4], "only last round doubles")
	t.equal(s.last_awards, [10, 6, 4, 2], "result screen receives actual doubled awards")
	s.record(result)
	t.equal(s.index, 3, "duplicate completion is ignored")
	t.equal(s.champion(), s.ranking()[0], "champion and podium agree")
	var rematch := s.rematch()
	t.equal(rematch.points, [0, 0, 0, 0], "rematch clears scores")
	t.equal(rematch.game_ids, s.game_ids, "rematch retains the schedule")
	t.ok(rematch.double_final, "rematch retains declared rules")
	t.test("tied leaders play a separate remapped reaction round")
	var tied := _session(1)
	tied.record(MatchResult.make("ring_rumble", "vortex_ring", [8, 8, 2, 1] as Array[int]))
	t.ok(not tied.is_complete(), "tie cannot crown slot zero")
	t.equal(tied.champion(), -1, "there is no winner yet")
	var cfg := tied.next_config()
	t.equal(cfg.minigame_id, "quick_draw", "reaction challenge breaks ties")
	t.equal(cfg.players.size(), 2, "only tied leaders participate")
	t.near(cfg.duration_override, 20, 0.001, "tie break is short")
	tied.record(MatchResult.make("quick_draw", cfg.arena_id, [0, 1] as Array[int]))
	t.equal(tied.champion(), 1, "winner maps back to the original player")
	t.ok(tied.is_complete(), "tie-break resolves cup")
	t.equal(tied.ranking()[0], 1, "podium shows tie-break winner first")
	t.test("repeated true draws terminate fairly")
	var draw := _session(1)
	draw.record(MatchResult.make("ring_rumble", "vortex_ring", [1, 1, 1, 1] as Array[int]))
	for i in TournamentSession.MAX_TIEBREAKS:
		draw.record(MatchResult.make("quick_draw", "", [0, 0, 0, 0] as Array[int]))
	t.ok(draw.is_complete(), "cup cannot loop forever")
	t.equal(draw.champion(), -1, "no arbitrary slot wins an unresolved draw")
	t.equal(draw.shared_champions.size(), 4, "all tied leaders share the cup")
	t.test("aborted and malformed results never advance the cup")
	var fresh := _session()
	result.finished_naturally = false
	fresh.record(result)
	t.equal(fresh.index, 0, "aborted result ignored")
	result.finished_naturally = true
	result.places[0] = 0
	fresh.record(result)
	t.equal(fresh.index, 0, "invalid placement ignored")
	t.test("short party races explicitly opt in without changing ordinary races")
	var quick := TournamentSession.from_preset("quick", _players(), 42, ["kart_sprint"])
	var race_config := quick.next_config()
	var race := load("res://src/minigames/kart_sprint.gd").new() as MiniGameController
	race.ctx = MatchContext.new()
	race.ctx.config = race_config
	t.equal(race.laps(), 1, "quick cup uses a single real lap")
	race_config.rules.erase("party_short_race")
	t.equal(race.laps(), 3, "ordinary races retain the minimum three laps")
	race.free()


func _saves(t: TestHarness) -> void:
	t.test("JSON round trip resumes the exact next game and rules")
	var s := _session()
	s.double_final = true
	s.match_rules = {"race_laps": 1, "maximum_duration": 180}
	s.players[0].local_profile_id = SaveSystem.active_profile_id()
	s.players[0].device_type = 2
	s.record(MatchResult.make("ring_rumble", "vortex_ring", [4, 3, 2, 1] as Array[int]))
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var restored := TournamentSession.restore(encoded)
	t.ok(restored != null, "saved cup restores")
	if restored != null:
		t.equal(restored.index, 1, "next round survives")
		t.equal(restored.points, s.points, "scores survive")
		t.equal(restored.next_config().seed, s.next_config().seed, "next round seed survives")
		t.ok(restored.double_final, "final rule survives")
		t.equal(restored.players[0].device_type, 2, "touch binding survives")
	var bad := encoded.duplicate(true)
	bad["version"] = 99
	t.ok(TournamentSession.restore(bad) == null, "future schema is not misread")
	bad = encoded.duplicate(true)
	bad["players"] = "corrupt"
	t.ok(TournamentSession.restore(bad) == null, "bad roster rejected")
	bad = encoded.duplicate(true)
	bad["games"] = ["unknown"]
	t.ok(TournamentSession.restore(bad) == null, "removed content cannot crash resume")
	bad = encoded.duplicate(true)
	bad["points"] = [-4, 3, 2, 1]
	t.ok(TournamentSession.restore(bad) == null, "negative scores rejected")
	s.checkpoint()
	t.ok(TournamentSession.saved_session() != null, "checkpoint is available to home screen")
	SaveSystem.set_shared_branch(TournamentSession.SAVE_BRANCH, {})
	t.test("favorites are unique, local, and exclude bosses")
	var id := Progression.playable_games()[0].id
	SaveSystem.set_player_branch("party", {})
	t.ok(PartyLibrary.toggle_favorite(id), "first toggle adds favorite")
	t.equal(PartyLibrary.favorites().size(), 1, "one favorite")
	t.ok(not PartyLibrary.toggle_favorite(id), "second toggle removes favorite")
	t.ok(not PartyLibrary.toggle_favorite("boss_forge"), "boss is not a normal playlist game")


func _settings(t: TestHarness) -> void:
	t.test("battery saver is a reversible effective override")
	UserSettings.set_value("battery_saver", false)
	UserSettings.set_value("fps_limit", 120)
	UserSettings.set_value("graphics_quality", 3)
	UserSettings.set_value("reduce_effects", false)
	UserSettings.set_value("battery_saver", true)
	t.equal(UserSettings.get_value("fps_limit"), 30, "saver caps at 30")
	t.equal(UserSettings.get_value("graphics_quality"), 0, "saver uses low quality")
	t.ok(UserSettings.get_value("reduce_effects"), "saver reduces effects")
	UserSettings.set_value("battery_saver", false)
	t.equal(UserSettings.get_value("fps_limit"), 120, "preferred FPS restored")
	t.equal(UserSettings.get_value("graphics_quality"), 3, "preferred quality restored")
	t.ok(not UserSettings.get_value("reduce_effects"), "effect preference retained")
	UserSettings.apply_touch_preset("left")
	t.ok(UserSettings.get_value("touch_left_handed"), "left-hand preset works")
	UserSettings.apply_touch_preset("small")
	t.near(UserSettings.get_value("touch_scale"), 0.8, 0.001, "small-hand preset works")
	UserSettings.apply_touch_preset("normal")


func _profiles(t: TestHarness) -> void:
	t.test("every named human earns their own stats; guests earn no host stats")
	var host_id := SaveSystem.active_profile_id()
	var second := SaveSystem.create_profile("Party test player")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 3, 1)
	cfg.players[0].local_profile_id = host_id
	cfg.players[1].local_profile_id = second
	cfg.players[2].display_name_override = "Guest"
	var before := Stats.total_matches()
	Stats.record_match(cfg, MatchResult.make("ring_rumble", "", [4, 9, 6, 1] as Array[int]))
	t.equal(Stats.total_matches(), before + 1, "host gets one match, not three")
	var data := SaveSystem.profile_branch(second, "stats")
	t.equal(int(data["matches"]), 1, "second player's match saved")
	t.equal(int(data["wins"]), 1, "second player's win saved")
	t.equal(SaveSystem.active_profile_id(), host_id, "reporting does not switch active profile")
	Stats.record_tournament(cfg.players, 1)
	t.equal(int(data["party_cups"]), 1, "cup saved for winner")
	t.equal(int(data["rivals"][host_id]["wins"]), 1, "head-to-head result saved")
	SaveSystem.delete_profile(second)


func _characters(t: TestHarness) -> void:
	t.test("eight recognizable archetypes with bounded perks and equal budgets")
	t.equal(Registry.characters().size(), 8, "eight characters retained")
	for c in Registry.characters():
		t.near(c.stat_total(), 3.0, 0.001, c.id + " has fixed stat budget")
		t.ok(Loc.has("archetype." + c.archetype), c.id + " archetype localized")
		t.ok(Loc.has("perk." + c.perk), c.id + " perk localized")
		t.ok(c.perk_scale >= 0.9 and c.perk_scale <= 1.1, c.id + " perk bounded")
		t.near(c.perk_factor("unknown"), 1, 0.001, "unrelated stats remain unchanged")


func _touch_geometry(t: TestHarness) -> void:
	t.test("all game controls fit separate local regions in both orientations")
	for viewport in [Vector2(1920, 1080), Vector2(1080, 1920)]:
		for count in [2, 3, 4]:
			for slot in count:
				var region := TouchSource.party_region(viewport, slot, count)
				t.ok(Rect2(Vector2.ZERO, viewport).encloses(region), "player region inside viewport")
				for other in slot:
					t.ok(not region.intersects(TouchSource.party_region(viewport, other, count)), "players have disjoint touch regions")
				for game in Registry.all_minigames():
					var touch := TouchSource.new()
					touch.profile = game.control_profile
					touch.buttons = ControlProfile.buttons_for(game.control_profile, game.control_hints)
					touch.touch_count = count
					touch.size = region.size
					touch._scale = minf(region.size.x / 700, region.size.y / 550)
					var controls := touch.editable_controls()
					var keys := controls.keys()
					for i in keys.size():
						var control: Dictionary = controls[keys[i]]
						var radius := float(control["radius"])
						t.ok(Rect2(Vector2.ZERO, region.size).encloses(Rect2(control["point"] - Vector2.ONE * radius, Vector2.ONE * radius * 2)), game.id + " control inside player region")
						for j in i:
							t.ok((control["point"] as Vector2).distance_to(controls[keys[j]]["point"]) >= radius + float(controls[keys[j]]["radius"]), game.id + " controls do not overlap")
					touch.free()
	var editor := TouchSource.new()
	editor.size = Vector2(1080, 1920)
	editor.profile = ControlProfile.Kind.ATV
	editor.buttons = ["shoot"]
	t.ok(editor.save_control_position("move", Vector2(600, 1100)), "custom position saved")
	t.near(editor._stick_centre().y, 1100, 1, "custom position applied")
	editor._haptics = false
	editor._handle_press(21, editor._stick_centre(), true)
	t.ok(editor._owners_has("move"), "relocated steering responds on its new side")
	editor._handle_press(21, Vector2.ZERO, false)
	t.ok(not editor.save_control_position("button_shoot", editor._stick_centre()), "overlapping customization rejected")
	editor.size = Vector2(1920, 1080)
	t.ok(editor._stick_centre().y != 1100, "portrait positions do not leak into landscape")
	editor.free()
	UserSettings.set_value("touch_positions", {})


func _touch_players(t: TestHarness, host: Node) -> void:
	t.test("four touch sources keep fingers and input frames independent")
	var sources: Array[TouchSource] = []
	for slot in 4:
		var touch := TouchSource.new()
		host.add_child(touch)
		InputRouter.assign_touch(slot)
		touch.setup(slot, Registry.minigame("tank_arena"), slot, 4)
		touch._haptics = false
		touch._handle_press(slot, touch._stick_centre(), true)
		touch._handle_drag(slot, touch._stick_centre() + Vector2(0, -80))
		touch._physics_process(0.016)
		sources.append(touch)
	InputRouter._physics_process(0.016)
	for slot in 4:
		t.ok(InputRouter.frame(slot).move.y < 0, "P%d receives movement" % slot)
		t.equal(sources[slot]._owners.size(), 1, "only own finger is captured")
	sources[0]._handle_press(0, Vector2.ZERO, false)
	sources[0]._physics_process(0.016)
	InputRouter._physics_process(0.016)
	t.equal(InputRouter.frame(0).move, Vector2.ZERO, "release stops player one")
	t.ok(InputRouter.frame(1).move.y < 0, "release cannot stop player two")
	for touch in sources:
		touch.queue_free()
	InputRouter.clear_all()
	await host.get_tree().process_frame


func _weapons(t: TestHarness, host: Node) -> void:
	t.test("pooled shells reset variant state")
	var shot := Projectile.new()
	host.add_child(shot)
	shot.bounces_left = 2
	shot.sticky_delay = 1
	shot.fire(Vector3.ZERO, Vector3.FORWARD, 0, 20, 25, 50)
	t.equal(shot.bounces_left, 0, "normal shot is not an old ricochet")
	t.near(shot.sticky_delay, 0, 0.001, "normal shot is not an old sticky")
	shot.arm_sticky(MatchContext.new(), 0.5)
	shot._attach(-1)
	shot.tick(0.6)
	t.ok(not shot.active, "sticky fuse expires without an infinite parked projectile")
	shot.queue_free()
	await host.get_tree().process_frame


func _validator(t: TestHarness) -> void:
	t.test("base default methods do not count as a game's scoring implementation")
	var base := MiniGameController.new()
	t.ok(not MiniGameValidator._overrides_any(base, ["compute_scores", "is_round_over"]), "missing implementation is detected")
	base.free()


func _tank_variants_and_pause(t: TestHarness, host: Node) -> void:
	t.test("tank ammo variants use the same match and bounded projectile pool")
	var scene = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	var cfg := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], 1, 1, 829)
	cfg.players[0].device_type = 2
	scene.setup({"config": cfg})
	await host.get_tree().process_frame
	var tank = scene.controller
	tank.shell_types[0] = 5
	tank.ammo[0] = 3
	var before: int = tank._shots.size()
	tank._fire(0)
	t.equal(tank._shots.size() - before, 3, "triple shell launches exactly three projectiles")
	t.equal(tank.ammo[0], 2, "a triple volley consumes one charge")
	var origin: Vector3 = scene.ctx.fighter(0).global_position + Vector3.UP
	tank._spawn_shell(0, 4, origin, Vector3.FORWARD)
	t.equal(tank._shots.back().bounces_left, 2, "ricochet gets two bounces")
	tank._spawn_shell(0, 6, origin, Vector3.FORWARD)
	t.ok(tank._shots.back().sticky_delay > 0, "sticky projectile has an armed fuse")
	t.test("background pause releases every finger and settings preserve the match")
	scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	scene._set_phase(MatchPhase.P.COUNTDOWN)
	scene._set_phase(MatchPhase.P.PLAYING)
	scene._on_app_backgrounded()
	t.ok(scene._paused, "background pauses play")
	for source in scene.touch_sources:
		t.ok(not source.is_processing_input(), "paused source cannot intercept settings touches")
	var settings = load("res://src/ui/screens/settings_screen.gd").new()
	scene.add_child(settings)
	var closed := [false]
	settings.setup({"in_match": true, "close_callback": func(): closed[0] = true})
	settings._refresh()
	settings.go_back()
	t.ok(closed[0], "embedded settings closes without routing away")
	t.ok(scene.ctx != null and scene._paused, "match and paused state survive settings")
	scene._toggle_pause()
	for source in scene.touch_sources:
		t.ok(source.is_processing_input(), "resume restores touch input")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _shared_cameras(t: TestHarness, host: Node) -> void:
	t.test("wide local arenas frame every competitor outside touch and score strips")
	var window := host.get_tree().root
	var original := window.size
	for game_id in ["tank_arena", "sabaq_sawarikh"]:
		var scene = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		var cfg := MatchConfig.build(game_id, ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 188)
		for p in cfg.players:
			p.device_type = 2
		scene.setup({"config": cfg})
		scene.set_physics_process(false)
		scene.camera._intro_left = 0.0
		t.ok(scene.camera.shared_world, "shared world view is selected for " + game_id)
		t.ok(scene.camera.local_target == null, "no single player owns the shared camera")
		for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
			window.size = resolution
			await host.get_tree().process_frame
			var viewport := window.get_visible_rect().size
			var radius: float = minf(scene.arena.current_radius * 0.4, 30.0)
			for slot in cfg.players.size():
				scene.ctx.fighter(slot).global_position = Vector3(-radius if slot % 2 == 0 else radius, 1.0, -radius if slot < 2 else radius)
			scene.camera._process(1.0)
			var controls_top := TouchSource.party_region(viewport, 0, 4).position.y
			var top: float = scene.hud.occupied_top()
			for fighter in scene.ctx.fighters:
				var pixel: Vector2 = scene.camera.unproject_position(fighter.global_position)
				t.ok(pixel.x > 0 and pixel.x < viewport.x, "shared player remains horizontally visible")
				t.ok(pixel.y > top and pixel.y < controls_top, "shared player remains in unobstructed play area")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	window.size = original
	await host.get_tree().process_frame


func _collector_decisions(t: TestHarness, host: Node) -> void:
	t.test("collector skill chooses less-contested visible loot without hidden buffs")
	var ctx := MatchContext.new()
	ctx.config = MatchConfig.build("gem_grab", ["fanoos", "fanoos"], 0, 1, 45)
	ctx.alive.assign([true, true])
	var world := Node3D.new()
	host.add_child(world)
	for i in 2:
		var fighter := Fighter.new()
		world.add_child(fighter)
		fighter.set_physics_process(false)
		fighter.position = Vector3(0, 1, 0) if i == 0 else Vector3(3.5, 1, 0)
		ctx.fighters.append(fighter)
	var contested := Collectible.new()
	var free := Collectible.new()
	world.add_child(contested)
	world.add_child(free)
	contested.add_to_group("pickups")
	free.add_to_group("pickups")
	contested.place(Vector3(4, 1, 0))
	free.place(Vector3(0, 1, 5))
	var brain = load("res://src/ai/brains/collector_brain.gd").new()
	brain.configure(0, ctx, PlayerConfig.Difficulty.EXPERT, 45)
	brain._tree = host.get_tree()
	t.equal(brain._preferred_loot(), free, "expert avoids loot the nearby rival will reach first")
	brain.strategy = 0.2
	t.equal(brain._preferred_loot(), contested, "easy collector follows nearest loot")
	var reaction: float = brain.reaction_time
	var accuracy: float = brain.accuracy
	brain._apply_personality(45, 0)
	t.near(brain.reaction_time, reaction, 0.0001, "personality does not bypass reaction delay")
	t.near(brain.accuracy, accuracy, 0.0001, "personality does not create perfect aim")
	world.queue_free()
	await host.get_tree().process_frame
