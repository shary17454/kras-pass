extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("duo network presentation")
	for arena_id in ["sweeper_ring", "bumper_bowl"]:
		var cfg := MatchConfig.build("duo_clash", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
		cfg.arena_id = arena_id
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		game._lives.assign([2, 1, 0, 2])
		game._team_score.assign([2, 4])
		game._publish()
		for slot in 4:
			scene.ctx.fighter(slot).damage_percent = slot * 12.5
		var replica = Replica.new()
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(replica.accept(packet, 4, "duo_clash", arena_id), "serialized team world accepted for selected arena")
		t.ok(not replica.accept(packet, 4, "duo_clash", "duel_pit"), "wrong expected arena rejected")
		for field in ["lives", "damage", "team_scores", "arena", "hazards"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "missing field rejected")
		for score in [-1, 0.5, 100001, NAN, INF, "2", true]:
			var bad := packet.duplicate(true)
			bad.world.team_scores[0] = score
			t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "invalid team score rejected")
		for key in ["lives", "damage", "team_scores"]:
			var bad := packet.duplicate(true)
			bad.world[key].pop_back()
			t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "wrong array length rejected")
		var bad := packet.duplicate(true)
		bad.world.lives[0] = 3
		t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "duo cannot acquire third life")
		bad = packet.duplicate(true)
		bad.world.hazards = {}
		t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "missing arena hazard state rejected")
		bad = packet.duplicate(true)
		bad.world.extra = 1
		t.ok(not replica.accept(bad, 4, "duo_clash", arena_id), "extra world field rejected")
		var scores: Array = Array(scene.ctx.scores).duplicate()
		game.on_round_start()
		for frame in 10:
			replica.render(scene, 0.016)
		for slot in 4:
			t.equal(game.lives(slot), int(packet.world.lives[slot]), "host lives restored")
			t.equal(scene.ctx.fighter(slot).damage_percent, float(packet.world.damage[slot]), "host damage restored")
			t.equal(game.team_score(slot % 2), int(packet.world.team_scores[slot % 2]), "partner HUD reads shared host team score")
		t.equal(Array(scene.ctx.scores), scores, "repeated presentation does not add points")
		t.ok(game._respawn_timers.is_empty(), "presentation cannot schedule respawns")
		if arena_id == "sweeper_ring":
			packet.world.hazards.angles = [0.25, -0.5, 0.75]
		else:
			packet.world.hazards.scales[0] = [1.25, 0.8, 1.25]
		t.ok(replica.accept(packet, 4, "duo_clash", arena_id), "arena visual update accepted")
		replica.render(scene, 0.016)
		var index := 0
		for hazard in scene.arena._hazards:
			if hazard is ArenaHazards.Sweeper:
				t.ok(is_equal_approx(hazard.rotation.y, float(packet.world.hazards.angles[index])), "sweeper transform matches host")
				t.equal(hazard._age, 0.0, "guest does not tick sweeper collision or acceleration")
				index += 1
			elif hazard is ArenaHazards.Bumper:
				var s: Array = packet.world.hazards.scales[index]
				t.ok(hazard._mesh.scale.is_equal_approx(Vector3(s[0], s[1], s[2])), "bumper transform matches host")
				t.ok(hazard._cooldowns.is_empty(), "guest does not tick bumper contact")
				index += 1
		t.equal(index, 3 if arena_id == "sweeper_ring" else 5, "all arena hazards presented")
		game.reset_lives()
		game.on_round_start()
		packet = replica.capture(scene)
		packet.round = 1
		t.ok(replica.accept(packet, 4, "duo_clash", arena_id), "new round state accepted")
		replica.render(scene, 0.016)
		t.equal(game._team_score, [0, 0], "new round clears team points")
		for slot in 4:
			t.equal(game.lives(slot), 2, "new round restores two lives")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
