extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("cooperative bosses retain individual contribution scoring")
	for id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"]:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 1872897823), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
			t.equal(fighter.teammates.size(), 3, id + " protects every other participant")
			for ally in scene.ctx.fighters:
				if ally.slot != fighter.slot:
					t.ok(fighter.teammates.has(ally.slot), id + " protection is symmetric")
		var victim: Fighter = scene.ctx.fighter(1)
		victim._invuln = 0.0
		var health := victim.health
		var impulse := victim._impulse
		t.ok(not victim.take_hit(0, Vector3.RIGHT, 11.0, 9.0), id + " ally attack is rejected")
		t.equal(victim.health, health, id + " ally attack cannot lower health")
		t.equal(victim._impulse, impulse, id + " ally attack cannot push another player into hazards")
		var ally: Fighter = scene.ctx.fighter(0)
		ally._pre_vel = Vector3.RIGHT * 12.0
		victim._pre_vel = Vector3.ZERO
		Fighter._contacts["0:1"] = {"a": ally, "b": victim, "into": Vector3.RIGHT}
		Fighter.resolve_impacts(1.0 / 60.0)
		t.equal(victim._impulse, impulse, id + " ally body impact cannot ram a teammate")
		t.equal(victim.health, health, id + " ally body impact cannot damage a teammate")
		victim._invuln = 0.0
		var enemy_health := victim.health
		t.ok(victim.take_hit(-1, Vector3.RIGHT, 11.0, 9.0, true), id + " boss/environment attacks remain effective")
		t.equal(victim.health, enemy_health - 9.0, id + " environment damage is unchanged")
		t.ok(not scene.ctx.definition.supports_teams, id + " results remain individual rather than pooled team scores")
		scene.controller.damage_boss(10.0, 0)
		scene.controller.damage_boss(20.0, 1)
		t.equal(scene.ctx.scores[0], 10, id + " contribution is credited to its attacker")
		t.equal(scene.ctx.scores[1], 20, id + " contribution is not shared with allies")
		victim.respawn_at(scene.controller.safe_respawn_position(1))
		t.ok(victim.teammates.has(0), id + " respawn retains cooperative protection")
		scene.controller.on_round_start()
		t.ok(victim.teammates.has(0), id + " next round retains cooperative protection")
		t.equal(scene.config.rule("boss_cooperative", false), true, id + " live config records cooperative policy for replays")
		var current := ReplayData.new()
		current.minigame_id = id
		current.rules = scene.config.rules.duplicate(true)
		t.equal(current.to_config().rule("boss_cooperative", false), true, id + " new recording preserves cooperative policy")
		var legacy := ReplayData.new()
		legacy.minigame_id = id
		t.equal(legacy.to_config().rule("boss_cooperative", true), false, id + " older recording retains rival-attack policy")
		t.empty(legacy.rules, id + " compatibility does not mutate stored replay rules")
		var legacy_config: MatchConfig = scene.config
		legacy_config.rules = legacy.to_config().rules
		for fighter in scene.ctx.fighters:
			fighter.teammates.clear()
		scene.controller.configure()
		t.empty(victim.teammates, id + " controller preserves legacy replay combat")
		victim._invuln = 0.0
		t.ok(victim.take_hit(0, Vector3.RIGHT, 11.0, 9.0), id + " legacy replay still applies its recorded rival attack")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
	var unrelated := ReplayData.new()
	unrelated.minigame_id = "ring_rumble"
	t.ok(not unrelated.to_config().rules.has("boss_cooperative"), "non-boss replay rules are unchanged")
	var arena: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(arena)
	arena.setup({"config": MatchConfig.build("ring_rumble", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 19), "on_finished": func(_r): pass})
	arena.set_physics_process(false)
	var rival: Fighter = arena.ctx.fighter(1)
	rival._invuln = 0.0
	t.empty(rival.teammates, "competitive arena does not inherit boss allies")
	t.ok(rival.take_hit(0, Vector3.RIGHT, 11.0, 9.0), "competitive arena rival attacks remain effective")
	arena.teardown()
	arena.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
