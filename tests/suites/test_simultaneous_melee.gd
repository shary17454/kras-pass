extends RefCounted

const DT := 1.0 / 60.0
const EPS := 0.00001
const ATTACK := InputFrame.Btn.ATTACK


func run(t: TestHarness, host: Node) -> void:
	t.suite("simultaneous melee is independent of fighter tick order")
	var errors_before := Log.error_count()
	for reverse in [false, true]:
		await _simultaneous(t, host, reverse)
		for attacker_slot in 2:
			for guard in ["single", "cooldown", "stun", "invuln", "shield", "range", "facing",
					"control", "frozen", "hitstop", "disabled"]:
				await _single_or_guard(t, host, reverse, attacker_slot, guard)
		for shield in [false, true]:
			for tied in [false, true]:
				await _multi_contender(t, host, reverse, shield, tied)
		await _legacy_tick(t, host, reverse)
		for revision in [0, 1]:
			await _playback_routing(t, host, reverse, revision)
		await _siege_callback_elimination(t, host, reverse)
	t.equal(Log.error_count(), errors_before, "focused regression logs no runtime errors")


func _fixture(t: TestHarness, host: Node, reverse: bool, count := 2) -> Dictionary:
	var characters: Array = []
	characters.resize(count)
	characters.fill("nabta")
	var cfg := MatchConfig.build("duel_pit", characters, count, 2, 117)
	cfg.allow_powerups = false
	cfg.sudden_death = false
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	scene.phase = MatchPhase.P.PLAYING
	scene.ctx.phase = MatchPhase.P.PLAYING
	scene._begin_play()
	scene._replay_enabled = false
	InputRouter.playback_mode = true
	for slot in count:
		var body: Fighter = scene.ctx.fighter(slot)
		body.set_physics_process(false)
		body.global_position = Vector3(0.0, 10.0, 1.5 * float(slot))
		body.facing = Vector3(0, 0, 1) if slot == 0 else Vector3(0, 0, -1)
		body.alive = true
		body.control_enabled = true
		body.can_attack = true
		body.can_jump = false
		body.can_dash = false
		body.ram_enabled = false
		body.health_defeat_enabled = false
		body.teammates.clear()
		body.velocity = Vector3.ZERO
		body._impulse = Vector3.ZERO
		body._hitstop = 0.0
		body._stun = 0.0
		body._invuln = 0.0
		body._attack_cd = 0.0
		body._attack_time = 0.0
		body.mods["frozen"] = 0.0
		body.mods["shield"] = 0.0
		body.reset_damage()
		InputRouter.apply_playback_frame(slot, InputFrame.new())
		t.equal(body.slot, slot, "context still maps slot to its own fighter")
		t.ok(scene._brains[slot] == null, "human fixture cannot publish AI input")
		t.equal(scene.controller.lives(slot), 3, "real duel starts with three lives")
	# ctx.fighters aliases the original array. Reverse a copy, not the slot map.
	scene._fighters = scene._fighters.duplicate()
	if reverse:
		scene._fighters.reverse()
	t.equal(scene._fighters[0].slot, count - 1 if reverse else 0, "requested tick order is active")
	t.equal(scene.ctx.fighter(0).slot, 0, "reversing ticks does not reverse context slots")
	t.equal(scene.ctx.fighter(1).slot, 1, "second context slot is also unchanged")
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	var separation := a.global_position.distance_to(b.global_position)
	t.near(separation, 1.5, EPS, "fixture is separated, inside melee range")
	t.greater(float(a._tuning.get("attack_range", 0.0)), separation, "authored melee reaches the rival")
	t.greater(a.facing.dot((b.global_position - a.global_position).normalized()), 0.99,
		"first fighter already faces the rival before movement")
	t.greater(b.facing.dot((a.global_position - b.global_position).normalized()), 0.99,
		"second fighter already faces the rival before movement")
	var swings: Array[int] = []
	var hits: Array[Vector2i] = []
	for body in scene.ctx.fighters:
		body.attacked.connect(func(slot: int): swings.append(slot))
	var on_hit := func(by: int, victim: int, _strength: float): hits.append(Vector2i(by, victim))
	EventBus.player_hit.connect(on_hit)
	return {"scene": scene, "swings": swings, "hits": hits, "on_hit": on_hit}


func _step(scene: Node, bits: Array[int]) -> void:
	for slot in bits.size():
		var frame := InputFrame.new()
		frame.bits = bits[slot]
		InputRouter.apply_playback_frame(slot, frame)
	scene._tick_live(DT)


func _simultaneous(t: TestHarness, host: Node, reverse: bool) -> void:
	t.test("both ready swings land in the same tick; reverse=%s" % reverse)
	var fixture := _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	for slot in 2:
		t.equal(InputRouter.frame(slot).bits, 0, "attack starts from a released frame")
	_step(scene, [ATTACK, ATTACK])
	for slot in 2:
		t.ok(InputRouter.frame(slot).just_pressed(ATTACK), "both attack edges belonged to this tick")
	var swings: Array = fixture.swings.duplicate()
	swings.sort()
	t.equal(swings, [0, 1], "both ready attackers swing, independent of execution order")
	t.equal(fixture.hits.size(), 2, "both reciprocal hits resolve in the request tick")
	t.ok(fixture.hits.has(Vector2i(0, 1)), "slot zero hits slot one")
	t.ok(fixture.hits.has(Vector2i(1, 0)), "slot one hits slot zero")
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	for body in [a, b]:
		t.near(body.damage_percent, float(body._tuning["attack_damage"]), EPS,
			"each duellist takes exactly one authored melee hit")
		t.near(body._attack_cd, float(body._tuning["attack_cooldown"]), EPS,
			"each accepted swing pays cooldown once, without an extra elapsed tick")
		t.near(body._attack_time, float(body._tuning["attack_duration"]), EPS,
			"swing starts immediately with the authored duration")
		t.greater(body._hitstop, 0.0, "each accepted victim retains hitstop")
		t.greater(body._stun, 0.0, "each accepted victim retains stun")
		t.greater(body._invuln, 0.0, "each accepted victim retains invulnerability")
		t.equal(scene.controller.lives(body.slot), 3, "melee damage alone cannot spend a life")
	t.near(a._hitstop, b._hitstop, EPS, "identical victims share the hitstop clock")
	t.near(a._stun, b._stun, EPS, "identical victims share the stun clock")
	t.near(a._invuln, b._invuln, EPS, "identical victims share the immunity clock")
	print("MELEE_ORDER_OBSERVATION=" + JSON.stringify({
		"reverse": reverse, "swings": fixture.swings, "hits": str(fixture.hits),
		"damage": [a.damage_percent, b.damage_percent],
		"cooldown": [a._attack_cd, b._attack_cd], "hitstop": [a._hitstop, b._hitstop]}))
	# Holding or releasing is not a new attack and must not retry a lost edge.
	var swing_count: int = fixture.swings.size()
	var hit_count: int = fixture.hits.size()
	_step(scene, [ATTACK, ATTACK])
	t.ok(not InputRouter.frame(0).just_pressed(ATTACK), "held button is not another edge")
	_step(scene, [0, 0])
	for tick in 22:
		_step(scene, [0, 0])
	t.equal(fixture.swings.size(), swing_count, "no unsolicited delayed or held-button swing")
	t.equal(fixture.hits.size(), hit_count, "no delayed damage after the original attack tick")
	await _dispose(fixture, host)


func _single_or_guard(t: TestHarness, host: Node, reverse: bool, attacker_slot: int, guard: String) -> void:
	t.test("%s; attacker=%d reverse=%s" % [guard, attacker_slot, reverse])
	var fixture := _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	var attacker: Fighter = scene.ctx.fighter(attacker_slot)
	var victim: Fighter = scene.ctx.fighter(1 - attacker_slot)
	match guard:
		"cooldown":
			attacker._attack_cd = 0.5
		"stun":
			attacker._stun = 0.5
		"invuln":
			victim._invuln = 0.5
		"shield":
			victim.mods["shield"] = 1.0
		"range":
			victim.global_position = attacker.global_position + attacker.facing * 3.0
		"facing":
			attacker.facing = -attacker.facing
		"control":
			attacker.control_enabled = false
		"frozen":
			attacker.mods["frozen"] = 0.5
		"hitstop":
			attacker._hitstop = 0.5
			attacker._attack_cd = 0.25
		"disabled":
			attacker.can_attack = false
	var fx_before: float = attacker._fx_time
	var bits: Array[int] = [0, 0]
	bits[attacker_slot] = ATTACK
	_step(scene, bits)
	var may_swing := guard not in ["cooldown", "stun", "control", "frozen", "hitstop", "disabled"]
	var expected_swings: Array[int] = []
	if may_swing:
		expected_swings.append(attacker_slot)
	t.equal(fixture.swings, expected_swings, "only an eligible requesting attacker swings")
	var lands := guard == "single"
	var expected_damage := float(attacker._tuning["attack_damage"]) if lands else 0.0
	t.near(victim.damage_percent, expected_damage, EPS, "single attack respects victim protection")
	t.near(attacker.damage_percent, 0.0, EPS, "idle victim never invents a return attack")
	t.near(victim._attack_cd, 0.0, EPS, "idle victim does not pay an attack cooldown")
	var expected_cd := float(attacker._tuning["attack_cooldown"]) if may_swing else 0.0
	if guard == "cooldown":
		expected_cd = 0.5 - DT
	elif guard == "hitstop":
		expected_cd = 0.25
	t.near(attacker._attack_cd, expected_cd, EPS, "cooldown advances once or starts once")
	if lands:
		t.equal(fixture.hits, [Vector2i(attacker_slot, victim.slot)], "single swing hits immediately")
		t.greater(victim._hitstop, 0.0, "single accepted hit still pauses its victim")
		t.greater(victim._stun, 0.0, "single accepted hit retains recovery cost")
		t.greater(victim._impulse.length(), 0.0, "single accepted hit retains knockback")
		t.near(victim._hitstop, float(victim._tuning["hitstop"]) - DT, EPS,
			"new hitstop starts before movement and consumes one shared tick")
		t.near(victim._stun, float(victim._tuning["hit_stun"]) * victim.data.perk_factor("recovery"), EPS,
			"fresh stun is not aged again after the prepared timers")
		t.near(victim._invuln, float(victim._tuning["hit_invuln"]) * victim.data.perk_factor("invulnerability"), EPS,
			"fresh immunity is not aged again after the prepared timers")
	elif guard == "shield":
		t.equal(fixture.hits, [Vector2i(attacker_slot, victim.slot)], "shield break retains its hit event")
		t.near(float(victim.mods["shield"]), 0.0, EPS, "shield is consumed instead of taking damage")
		t.greater(victim._invuln, 0.0, "shield break retains protective immunity")
		t.near(victim._invuln, 0.4, EPS, "shield immunity is not aged again in this tick")
	else:
		t.empty(fixture.hits, "blocked attack cannot emit a hit")
	if not lands:
		t.near(victim._hitstop, 0.0, EPS, "blocked damage cannot create hitstop")
		t.near(victim._stun, 0.0, EPS, "blocked damage cannot create stun")
		t.near(victim._impulse.length(), 0.0, EPS, "blocked damage cannot create knockback")
	if guard == "stun":
		t.near(attacker._stun, 0.5 - DT, EPS, "existing stun is not bypassed or counted twice")
	if guard == "invuln":
		t.near(victim._invuln, 0.5 - DT, EPS, "existing immunity advances exactly once")
	if guard == "frozen":
		t.near(float(attacker.mods["frozen"]), 0.5 - DT, EPS, "freeze advances exactly once")
	if guard == "hitstop":
		t.near(attacker._hitstop, 0.5 - DT, EPS, "initial hitstop advances exactly once")
		t.near(attacker._fx_time, fx_before, EPS, "initial hitstop still pauses ordinary timers")
	for slot in 2:
		t.equal(scene.controller.lives(slot), 3, "control case does not spend duel lives")
	await _dispose(fixture, host)


func _multi_contender(t: TestHarness, host: Node, reverse: bool, shield: bool, tied: bool) -> void:
	t.test("three contenders retain one-hit immunity; reverse=%s shield=%s tied=%s" % [reverse, shield, tied])
	var fixture := _fixture(t, host, reverse, 4)
	var scene: Node = fixture.scene
	var victim: Fighter = scene.ctx.fighter(0)
	var closer: Fighter = scene.ctx.fighter(1)
	var farther: Fighter = scene.ctx.fighter(2)
	var third: Fighter = scene.ctx.fighter(3)
	victim.global_position = Vector3(0, 10, 0)
	closer.global_position = Vector3(-1.75 if tied else -1.25, 10, 0)
	closer.facing = Vector3.RIGHT
	farther.global_position = Vector3(1.75, 10, 0)
	farther.facing = Vector3.LEFT
	third.global_position = Vector3(0, 10, -2.0)
	third.facing = Vector3.BACK
	if shield:
		victim.mods["shield"] = 1.0
	_step(scene, [0, ATTACK, ATTACK, ATTACK])
	var swings: Array = fixture.swings.duplicate()
	swings.sort()
	t.equal(swings, [1, 2, 3], "all three contenders spend their ready swings")
	t.equal(fixture.hits, [Vector2i(1, 0)], "closer hit wins independent of the fighter loop")
	t.near(victim.damage_percent, 0.0 if shield else float(closer._tuning["attack_damage"]), EPS,
		"one immunity window accepts at most one hit, including shield break")
	t.near(closer.damage_percent, 0.0, EPS, "contenders remain outside each other's reach")
	t.near(farther.damage_percent, 0.0, EPS, "farther contender receives no phantom hit")
	t.near(third.damage_percent, 0.0, EPS, "third contender receives no phantom hit")
	t.greater(victim._invuln, 0.0, "winning contact retains normal one-hit protection")
	if shield:
		t.near(float(victim.mods["shield"]), 0.0, EPS, "shield absorbs the first hit, not the whole batch")
	t.ok(not victim.take_hit(2, Vector3.LEFT, 20.0, 9.0),
		"normal take_hit still rejects a later contender during immunity")
	t.equal(fixture.hits.size(), 1, "no global immunity bypass is left behind")
	await _dispose(fixture, host)


func _legacy_tick(t: TestHarness, host: Node, reverse: bool) -> void:
	t.test("standalone tick retains recorded legacy order; reverse=%s" % reverse)
	var fixture := _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	for body in scene._fighters:
		var frame := InputFrame.new()
		frame.bits = ATTACK
		body.tick(frame, DT)
	var first := 1 if reverse else 0
	t.equal(fixture.swings, [first], "legacy standalone tick preserves the original first swing")
	t.equal(fixture.hits, [Vector2i(first, 1 - first)], "legacy standalone tick keeps recorded damage order")
	await _dispose(fixture, host)


func _playback_routing(t: TestHarness, host: Node, reverse: bool, revision: int) -> void:
	t.test("playback routes combat revision %d; reverse=%s" % [revision, reverse])
	var fixture := _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	var packet := PackedByteArray()
	for slot in 2:
		var frame := InputFrame.new()
		frame.bits = ATTACK
		packet.append_array(frame.encode())
	var replay := ReplayData.from_match(scene.config, [packet], {}, {}, null)
	replay.combat_revision = revision
	scene.playback = replay
	scene._playback_frames.assign([InputFrame.new(), InputFrame.new()])
	scene._tick_live(DT)
	if revision == 0:
		var first := 1 if reverse else 0
		t.equal(fixture.swings, [first], "revision zero explicitly retains legacy combat")
		t.equal(fixture.hits, [Vector2i(first, 1 - first)], "legacy playback retains recorded first-hit result")
	else:
		var swings: Array = fixture.swings.duplicate()
		swings.sort()
		t.equal(swings, [0, 1], "revision one uses simultaneous combat")
		t.equal(fixture.hits.size(), 2, "new playback resolves both attacks in one tick")
		for body in scene.ctx.fighters:
			t.near(body.damage_percent, float(body._tuning["attack_damage"]), EPS,
				"new playback preserves the reciprocal hit result")
	t.equal(scene.playback_tick, 1, "one playback frame is consumed, not two")
	await _dispose(fixture, host)


func _siege_callback_elimination(t: TestHarness, host: Node, reverse: bool) -> void:
	t.test("crystal callback cannot emit a stale prepared swing; reverse=%s" % reverse)
	var cfg := MatchConfig.build("base_siege", ["nabta", "nabta"], 2, 2, 117)
	cfg.allow_powerups = false
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	scene.phase = MatchPhase.P.PLAYING
	scene.ctx.phase = MatchPhase.P.PLAYING
	scene._begin_play()
	scene._replay_enabled = false
	InputRouter.playback_mode = true
	var swings: Array[int] = []
	for slot in 2:
		var body: Fighter = scene.ctx.fighter(slot)
		var target: Dictionary = scene.controller._bases[1 - slot]
		target.health = 13.0
		target.cooldown = 0.0
		body.global_position = target.node.global_position + Vector3(0, 0, 2)
		body.facing = Vector3.FORWARD
		body.velocity = Vector3.ZERO
		body._impulse = Vector3.ZERO
		body._stun = 0.0
		body._hitstop = 0.0
		body._invuln = 0.0
		body._attack_cd = 0.0
		body.can_dash = false
		body.can_jump = false
		body.ram_enabled = false
		body.attacked.connect(func(attacker: int): swings.append(attacker))
		InputRouter.apply_playback_frame(slot, InputFrame.new())
	scene._fighters = scene._fighters.duplicate()
	if reverse:
		scene._fighters.reverse()
	var first := 1 if reverse else 0
	_step(scene, [ATTACK, ATTACK])
	t.equal(swings, [first], "game-rule elimination cancels the later owner's signal")
	t.ok(not scene.ctx.is_alive(1 - first), "destroying the rival crystal actually eliminates its owner")
	t.ok(scene.ctx.is_alive(first), "stale prepared callback cannot destroy the survivor's crystal")
	t.near(scene.controller.base_health(1 - first), 0.0, EPS, "first real callback destroys its target")
	t.near(scene.controller.base_health(first), 13.0, EPS, "inactive owner's prepared command cannot score")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _dispose(fixture: Dictionary, host: Node) -> void:
	EventBus.player_hit.disconnect(fixture.on_hit)
	var scene: Node = fixture.scene
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
