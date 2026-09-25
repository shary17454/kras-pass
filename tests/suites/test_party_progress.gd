extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("party profiles, podium and announcer")
	var backup := SaveSystem.profile().duplicate(true)
	var settings := SaveSystem.settings().duplicate(true)
	var active := SaveSystem.create_profile("Party owner")
	var second := SaveSystem.create_profile("Party friend")
	SaveSystem.switch_profile(active)
	var cfg := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], 3, 1)
	cfg.players[0].local_profile_id = active
	cfg.players[1].local_profile_id = second
	cfg.players[2].display_name_override = "Guest"
	var result := MatchResult.make("tank_arena", cfg.arena_id, [2, 4, 1, 0] as Array[int])
	result.duration = 60
	result.details[1] = {"powerups": 3, "knockouts": 2}
	t.test("every named participant owns their reward; guests do not")
	Stats.record_match(cfg, result)
	t.equal(SaveSystem.active_profile_id(), active, "reward processing never changes the active profile")
	t.equal(Stats.total_matches(), 1, "active profile gets one match")
	t.equal(Stats.total_wins(), 0, "friend's win is not credited to owner")
	t.equal(Stats.powerups_collected(), 0, "friend's pickups are not credited to owner")
	t.near(Stats.play_seconds(), 60, 0.001, "only completed gameplay counts, not menus")
	var friend_stats := SaveSystem.profile_branch(second, "stats")
	t.equal(friend_stats.get("wins"), 1, "friend earns the win")
	t.equal(friend_stats.get("powerups"), 3, "friend earns their pickups")
	t.ok(SaveSystem.profile_branch(second, "achievements").has("first_win"), "inactive friend earns achievement")
	t.ok(not SaveSystem.profile_branch(second, "achievements").has("sure_footed"), "a no-fall award requires a falling arena, not tanks or memory")
	t.ok(not Achievements.is_unlocked("first_win"), "owner does not get friend's achievement")
	t.equal(SaveSystem.profile_branch(second, "progress").get("gems"), 3, "friend earns win gems")
	t.equal(Progression.gems(), 1, "owner earns participation gems")
	Stats.record_match(cfg, result)
	t.equal(Stats.total_matches(), 1, "repeated result callback is idempotent")
	t.equal(SaveSystem.profile_branch(second, "progress").get("gems"), 3, "no duplicate gems")
	var training := result.duplicate(true) as MatchResult
	training.remove_meta("stats_recorded")
	cfg.context = MatchConfig.Context.TRAINING
	Stats.record_match(cfg, training)
	t.equal(Stats.total_matches(), 1, "training does not farm rewards")
	cfg.context = MatchConfig.Context.QUICK
	training.finished_naturally = false
	Stats.record_match(cfg, training)
	t.equal(Stats.total_matches(), 1, "aborted matches give no rewards")
	t.test("cup awards survive checkpoints and are not a scoring bonus")
	var cup := TournamentSession.new()
	cup.setup(cfg.players, ["ring_rumble", "tank_arena", "ring_rumble"] as Array[String], 124)
	var first := MatchResult.make("ring_rumble", "", [4, 0, 3, 2] as Array[int])
	first.details[1] = {"falls": 3, "knockouts": 2}
	cup.record(first)
	t.ok(cup.trailed_last.has(1), "last-place history retained")
	var resumed := TournamentSession.restore(JSON.parse_string(JSON.stringify(cup.to_dict())))
	t.ok(resumed != null, "cup restores")
	if resumed != null:
		t.equal(resumed.run_id, cup.run_id, "cup identity survives restart for exactly-once rewards")
		t.equal(resumed.performance[1].get("falls"), 3, "award totals survive restart")
		t.ok(resumed.trailed_last.has(1), "comeback history survives restart")
		resumed.record(MatchResult.make("tank_arena", "", [0, 4, 2, 3] as Array[int]))
		resumed.record(MatchResult.make("ring_rumble", "", [0, 4, 2, 3] as Array[int]))
		t.equal(resumed.champion(), 1, "friend wins comeback cup")
		t.equal(resumed.points, [7, 11, 7, 8], "fun awards never alter points")
		t.equal(SaveSystem.profile_branch(second, "progress").get("tournaments_won"), 1, "nonactive winner gets cup progression")
		t.equal(SaveSystem.profile_branch(second, "progress").get("gems"), 12, "cup bonus is granted once")
		t.equal(Progression.tournaments_won(), 0, "loser never inherits cup")
		t.ok(SaveSystem.profile_branch(second, "achievements").has("comeback_cup"), "comeback achievement belongs to winner")
		t.ok(resumed.fun_awards().any(func(a): return a["key"] == "party.award.comeback"), "comeback appears on podium")
		resumed._complete_or_save()
		t.equal(SaveSystem.profile_branch(second, "progress").get("gems"), 12, "duplicate final cannot grant another cup")
		Stats.record_tournament(cfg.players, 1, [], [1] as Array[int], resumed.run_id + ":cup")
		t.equal(SaveSystem.profile_branch(second, "progress").get("gems"), 12, "persisted receipt rejects duplicate completion after restart")
		t.ok(resumed.rematch().fun_awards().is_empty(), "rematch clears award counters")
		t.ok(resumed.rematch().run_id != resumed.run_id, "intentional rematch can earn fresh rewards")
		var podium := TournamentPodium.new()
		host.add_child(podium)
		podium.setup(resumed)
		podium.queue_free()
	t.test("shared cups recognize all tied profiles once")
	Stats.record_tournament(cfg.players, -1, [0, 1] as Array[int])
	t.equal(Progression.tournaments_won(), 1, "first cochampion rewarded")
	t.equal(SaveSystem.profile_branch(second, "progress").get("tournaments_won"), 2, "second cochampion rewarded")
	var ring_config := MatchConfig.build("ring_rumble", ["nabta", "sakhra"], 2, 1)
	ring_config.players[0].local_profile_id = active
	ring_config.players[1].local_profile_id = second
	var ring_result := MatchResult.make("ring_rumble", ring_config.arena_id, [0, 1] as Array[int])
	ring_result.duration = 20
	Stats.record_match(ring_config, ring_result)
	t.ok(SaveSystem.profile_branch(second, "achievements").has("sure_footed"), "completed push-out win without a fall earns the award")
	var wins_before := int(SaveSystem.profile_branch(second, "stats")["per_game"]["ring_rumble"]["wins"])
	var drawn := MatchResult.make("ring_rumble", ring_config.arena_id, [1, 1] as Array[int])
	Stats.record_match(ring_config, drawn)
	t.equal(int(SaveSystem.profile_branch(second, "stats")["per_game"]["ring_rumble"]["wins"]), wins_before, "a shared draw does not farm game-win achievements")
	var saved_match := MatchResult.make("ring_rumble", ring_config.arena_id, [0, 1] as Array[int])
	ring_config.rules["party_progress_token"] = "regression-match-1"
	Stats.record_match(ring_config, saved_match)
	var gems_after := int(SaveSystem.profile_branch(second, "progress")["gems"])
	var reconstructed := MatchResult.make("ring_rumble", ring_config.arena_id, [0, 1] as Array[int])
	Stats.record_match(ring_config, reconstructed)
	t.equal(int(SaveSystem.profile_branch(second, "progress")["gems"]), gems_after, "new result instance after restore cannot duplicate match reward")
	t.test("favorite character and palette are profile-local and serialized")
	var friend_progress := Progression.prepare_profile(second)
	friend_progress["last_character"] = "ramla"
	var palettes := Registry.palettes()
	var palette_id := String(palettes[palettes.size() - 1].get("id", "classic"))
	friend_progress["palettes"].append(palette_id)
	friend_progress["selected_palette"] = palette_id
	SaveSystem.set_profile_branch(second, "progress", friend_progress)
	cfg.players[1].apply_profile_preferences()
	t.equal(cfg.players[1].character_id, "ramla", "friend preference applied")
	t.equal(cfg.players[1].palette_id, palette_id, "friend palette applied, not owner's")
	var decoded := PlayerConfig.from_dict(JSON.parse_string(JSON.stringify(cfg.players[1].to_dict())))
	t.equal(decoded.palette_id, palette_id, "replay/checkpoint keeps exact cosmetics")
	t.near(decoded.character_with_cosmetics().speed, Registry.character("ramla").speed, 0.0001, "cosmetics cannot change speed")
	var recorded_frame := PackedByteArray()
	recorded_frame.resize(InputFrame.BYTES * cfg.players.size())
	var replay := ReplayData.from_match(cfg, [recorded_frame], {}, {}, result)
	var playback := ReplayData.from_dict(replay.to_dict())
	t.ok(playback != null, "replay metadata supports palettes without breaking its schema")
	if playback != null:
		var replay_player := playback.to_config().players[1]
		t.equal(replay_player.palette_id, palette_id, "real replay conversion preserves cosmetic selection")
		t.equal(replay_player.character_with_cosmetics().color, decoded.character_with_cosmetics().color, "virtual replay player retains original color")
	t.test("announcer volume is independent and missing voices are harmless")
	UserSettings.set_value("announcer_enabled", true)
	UserSettings.set_value("volume_announcer", 0.5)
	UserSettings.set_value("volume_master", 0.8)
	UserSettings.set_value("music_enabled", false)
	UserSettings.set_value("volume_sfx", 0.25)
	var request := AudioManager.announcement_request("announcer.go", "ar", PackedStringArray(["test-voice"]))
	t.equal(request.get("volume"), 40, "master times announcer, independent from music and SFX")
	t.near(UserSettings.volume_linear("sfx"), 0.2, 0.001, "announcer leaves effects level alone")
	t.ok(AudioManager.announcement_request("announcer.go", "ar", []).is_empty(), "no installed voice does not crash")
	UserSettings.set_value("announcer_enabled", false)
	t.ok(AudioManager.announcement_request("announcer.go", "ar", ["test-voice"]).is_empty(), "announcer toggle mutes speech")
	t.test("music ducking cannot restore stale volume settings")
	var was_enabled := AudioManager.enabled
	AudioManager.enabled = true
	UserSettings.set_value("music_enabled", true)
	UserSettings.set_value("volume_master", 1.0)
	UserSettings.set_value("volume_music", 0.7)
	AudioManager.duck(-10, 0.01)
	UserSettings.set_value("volume_music", 0.2)
	await host.get_tree().create_timer(0.35).timeout
	var bus := AudioServer.get_bus_index("Music")
	t.near(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.2, 0.001, "duck release respects the latest slider")
	AudioManager.duck(-8, 0.01)
	AudioManager.set_suspended(true)
	await host.get_tree().create_timer(0.35).timeout
	t.ok(AudioServer.is_bus_mute(bus), "duck release cannot unmute background audio")
	AudioManager.set_suspended(false)
	AudioManager.enabled = was_enabled
	SaveSystem.set_profile(backup)
	SaveSystem.profile_loaded.emit(backup)
	SaveSystem.set_settings(settings)
	_playlists(t)
	await host.get_tree().process_frame


func _playlists(t: TestHarness) -> void:
	t.test("portable tournament plans contain no local identities")
	var plan := PartyPlaylist.create_plan()
	plan["name"] = "Family cup"
	plan["private_profile"] = "must not travel"
	plan["entries"][0]["token"] = "must not travel"
	var code := PartyPlaylist.encode(plan)
	var decoded := PartyPlaylist.decode(code)
	t.ok(not decoded.is_empty(), "code imports locally")
	t.ok(not decoded.has("private_profile"), "only allowlisted plan fields are shared")
	t.ok(not decoded["entries"][0].has("token"), "entry extras are removed")
	t.equal(decoded["seed"], plan["seed"], "random seed survives sharing")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1)
	var cup := PartyPlaylist.make_session(decoded, cfg.players)
	t.ok(cup != null, "imported plan launches")
	if cup != null:
		t.equal(cup.game_ids[0], decoded["entries"][0]["game"], "selected game order is preserved")
		t.equal(cup.arena_ids[0], decoded["entries"][0]["arena"], "selected map is preserved")
		t.equal(cup.seed_value, decoded["seed"], "launch uses shared seed")
	t.ok(PartyPlaylist.decode(code + "corrupt").is_empty(), "corrupt checksum rejected")
	t.ok(PartyPlaylist.decode("KP1.@@!!.abcd").is_empty(), "invalid base64 rejected without a decoder error")
	t.ok(PartyPlaylist.decode("KP1.".repeat(3000)).is_empty(), "oversized code rejected before parsing")
	var invalid := decoded.duplicate(true)
	invalid["catalog"] = "outdated"
	t.ok(not PartyPlaylist.valid(invalid), "different content revision rejected")
	invalid = decoded.duplicate(true)
	invalid["entries"][0]["arena"] = "not-a-map"
	t.ok(not PartyPlaylist.valid(invalid), "incompatible arena rejected")
	invalid = decoded.duplicate(true)
	invalid["seed"] = -1
	t.ok(not PartyPlaylist.valid(invalid), "negative seed rejected")
	invalid["seed"] = {}
	t.ok(not PartyPlaylist.valid(invalid), "structured value cannot be cast to a seed")
	invalid = decoded.duplicate(true)
	invalid["entries"] = []
	t.ok(not PartyPlaylist.valid(invalid), "empty schedule rejected")
	var saved := SaveSystem.profile().duplicate(true)
	t.ok(PartyPlaylist.save(decoded), "named plan saved")
	PartyPlaylist.remove(decoded["name"])
	t.ok(not PartyPlaylist.saved().has(decoded["name"]), "only selected saved plan removed")
	var other := SaveSystem.create_profile("Separate playlists")
	SaveSystem.switch_profile(other)
	t.ok(PartyPlaylist.saved().is_empty(), "saved plans are per profile")
	SaveSystem.set_profile(saved)
	SaveSystem.profile_loaded.emit(saved)
