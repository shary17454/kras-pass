extends RefCounted

const DT := 1.0 / 60.0
const EPS := 0.00001
const ATTACK := InputFrame.Btn.ATTACK


func run(t: TestHarness, host: Node) -> void:
	t.suite("BaseSiege atomic actions through real MatchScene live tick")
	for revision in [-1, 0, 1, 2]:
		for reverse in [false, true]:
			for mode in ["attack", "ram"]:
				await _exchange(t, host, reverse, revision, mode, "fatal")
			await _mixed(t, host, reverse, revision)
			await _ram_contenders(t, host, reverse, revision)
			await _swing_ram_priority(t, host, reverse, revision)
	for reverse in [false, true]:
		for mode in ["attack", "ram"]:
			for guard in ["nonfatal", "base_cooldown", "empty", "range", "dead"]:
				await _exchange(t, host, reverse, -1, mode, guard)
		for guard in ["cooldown", "facing", "stun", "frozen", "hitstop", "control", "disabled"]:
			await _exchange(t, host, reverse, -1, "attack", guard)
		await _contenders(t, host, reverse)
		await _presentation_only(t, host, reverse)


func _fixture(t: TestHarness, host: Node, reverse: bool, count := 2) -> Dictionary:
	var characters: Array = []
	characters.resize(count)
	characters.fill("fanoos")
	var cfg := MatchConfig.build("base_siege", characters, count, 1, 220000000)
	cfg.allow_powerups = false
	cfg.sudden_death = false
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	scene.set_process(false)
	scene._begin_play()
	scene._replay_enabled = false
	InputRouter.playback_mode = true
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	var originals: Array[Fighter] = scene.ctx.fighters.duplicate()
	for slot in count:
		var base: Dictionary = scene.controller._bases[slot]
		base.node.global_position = Vector3(-10.0 + 20.0 * slot, 0, 0)
		base.health = 13.0
		base.cooldown = 0.0
		base.hits = 0
	for body in originals:
		body.set_physics_process(false)
		body.global_position = scene.controller._bases[1 - body.slot if body.slot < 2 else 0].node.global_position + Vector3(0, 1.3, 2)
		body.facing = Vector3.FORWARD
		body.velocity = Vector3.ZERO
		body._impulse = Vector3.ZERO
		body._stun = 0.0
		body._hitstop = 0.0
		body._invuln = 0.0
		body._attack_cd = 0.0
		body._attack_time = 0.0
		body._dash_time = 0.0
		body.can_dash = false
		body.can_jump = false
		body.can_attack = true
		body.control_enabled = true
		body.ram_enabled = false
		body.mods["frozen"] = 0.0
		body.mods["points"] = 1.0
		InputRouter.apply_playback_frame(body.slot, InputFrame.new())
		t.ok(scene._brains[body.slot] == null, "fixture has no AI")
		t.ok(PhysicsServer3D.body_get_space(body.get_rid()).is_valid(), "real physics space registered")
	scene._fighters = scene._fighters.duplicate()
	if reverse:
		scene._fighters.reverse()
		# Rams iterate bases, not fighter execution order: reverse only that copy too.
		scene.controller._bases = scene.controller._bases.duplicate()
		scene.controller._bases.reverse()
	t.ok(not scene.powerups.enabled and scene.machine == null, "no powerups or hover machine")
	var swings: Array = []
	var hits: Array = []
	for body in originals:
		body.attacked.connect(func(slot: int): swings.append(slot))
	var on_hit := func(by: int, victim: int, strength: float): hits.append([by, victim, strength])
	EventBus.player_hit.connect(on_hit)
	return {"scene": scene, "originals": originals, "swings": swings, "hits": hits, "on_hit": on_hit}


func _step(scene: Node, revision: int, bits: Array[int]) -> void:
	if revision >= 0:
		var packet := PackedByteArray()
		for bit in bits:
			var frame := InputFrame.new()
			frame.bits = bit
			packet.append_array(frame.encode())
		var replay := ReplayData.from_match(scene.config, [packet], {}, {}, null)
		replay.combat_revision = revision
		scene.playback = replay
		scene._playback_frames.clear()
		for slot in bits.size():
			scene._playback_frames.append(InputFrame.new())
	else:
		for slot in bits.size():
			var frame := InputFrame.new()
			frame.bits = bits[slot]
			InputRouter.apply_playback_frame(slot, frame)
	scene._tick_live(DT)


func _base(game: Node, slot: int) -> Dictionary:
	for base in game._bases:
		if int(base.slot) == slot:
			return base
	return {}


func _exchange(t: TestHarness, host: Node, reverse: bool, revision: int, mode: String, guard: String) -> void:
	t.test("%s %s revision=%d reverse=%s" % [mode, guard, revision, reverse])
	var fixture := await _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	var game: Node = scene.controller
	var damage := 9.0 if mode == "ram" else 13.0
	var hp := 2.0 * damage if guard == "nonfatal" else damage
	var bits: Array[int] = [0, 0]
	if mode == "attack": bits.fill(ATTACK)
	for slot in 2:
		var base := _base(game, slot)
		base.health = hp
		if guard == "base_cooldown":
			base.cooldown = 0.3
		var body: Fighter = scene.ctx.fighter(slot)
		if mode == "ram" and guard != "empty":
			body._dash_time = 0.2
		if guard == "empty": bits[slot] = 0
		if guard == "range": body.global_position.z = 5.0
		if guard == "facing": body.facing = Vector3.BACK
		if guard == "cooldown": body._attack_cd = 0.3
		if guard == "stun": body._stun = 0.3
		if guard == "hitstop": body._hitstop = 0.3
		if guard == "frozen": body.mods["frozen"] = 0.3
		if guard == "control": body.control_enabled = false
		if guard == "disabled": body.can_attack = false
		if guard == "dead":
			scene.ctx.alive[slot] = false
			body.alive = false
		var to: Vector3 = _base(game, 1 - slot).node.global_position - body.global_position
		to.y = 0.0
		if guard != "range": t.near(to.length(), 2.0, EPS, "base target horizontal distance fixed")
	t.greater(scene.ctx.fighter(0).global_position.distance_to(scene.ctx.fighter(1).global_position), 19.0, "no nearby melee")
	_step(scene, revision, bits)
	var health := [game.base_health(0), game.base_health(1)]
	var scores := Array(scene.ctx.scores)
	var blocked := guard not in ["fatal", "nonfatal"]
	var atomic := revision == -1 or revision >= 2
	if blocked:
		t.equal(health, [hp, hp], "guard rejects damage")
		t.equal(scores, [0, 0], "guard grants no score")
	elif guard == "nonfatal":
		t.equal(health, [damage, damage], "nonfatal authored damage on both targets")
		t.equal(scores, [1, 1], "one nonfatal hit credit each")
		for slot in 2:
			t.near(float(_base(game, slot).cooldown), 0.3 - DT if mode == "attack" else 0.3, EPS,
				"swing/ram cooldown keeps its original clock age")
	elif atomic:
		t.equal(health, [0.0, 0.0], "both fatal commands commit in one live tick")
		t.equal(Array(scene.ctx.alive), [false, false], "both base owners eliminated after commands")
		t.equal(scores, [7, 7], "both hit and destruction credits awarded")
		var result := MatchResult.make("base_siege", scene.config.arena_id, game.compute_scores())
		t.ok(result.is_draw(), "production score computation produces a draw")
	else:
		var first := (0 if reverse else 1) if mode == "ram" else (1 if reverse else 0)
		var expected_health: Array = [hp, hp]
		expected_health[1 - first] = 0.0
		var expected_scores: Array = [0, 0]
		expected_scores[first] = 7
		t.equal(health, expected_health, "revision zero/one retains ordered BaseSiege damage")
		t.equal(scores, expected_scores, "revision zero/one retains historical winner")
	for slot in 2:
		t.ok(scene.ctx.fighter(slot) == fixture.originals[slot], "context slot identity never reverses")
		t.near(scene.ctx.fighter(slot).damage_percent, 0.0, EPS, "no direct fighter damage")
		t.ok(int(scene.ctx.details[slot].get("base_hits", 0)) <= 1, "at most one hit credit")
		t.ok(int(scene.ctx.details[slot].get("bases_broken", 0)) <= 1, "at most one destruction credit")
	if revision >= 0: t.equal(scene.playback_tick, 1, "real playback consumes exactly one frame")
	t.empty(fixture.hits, "base actions do not hit a fighter")
	print("BASE_ATOMIC_OBSERVATION=" + JSON.stringify({"revision": revision, "mode": mode, "guard": guard, "reverse": reverse, "health": health, "scores": scores, "alive": scene.ctx.alive, "details": scene.ctx.details, "swings": fixture.swings}))
	await _dispose(fixture, host)


func _mixed(t: TestHarness, host: Node, reverse: bool, revision: int) -> void:
	t.test("attack and ram share frame revision=%d reverse=%s" % [revision, reverse])
	var fixture := await _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	_base(scene.controller, 0).health = 9.0
	_base(scene.controller, 1).health = 13.0
	scene.ctx.fighter(1)._dash_time = 0.2
	_step(scene, revision, [ATTACK, 0])
	if revision == -1 or revision >= 2:
		t.equal([scene.controller.base_health(0), scene.controller.base_health(1)], [0.0, 0.0],
			"ready ram survives same-frame rival base attack")
		t.equal(Array(scene.ctx.scores), [7, 7], "mixed actions award both destruction credits")
		t.equal(Array(scene.ctx.alive), [false, false], "mixed actions eliminate both owners")
	else:
		t.equal([scene.controller.base_health(0), scene.controller.base_health(1)], [9.0, 0.0],
			"old revisions retain attack-before-ram elimination")
		t.equal(Array(scene.ctx.scores), [7, 0], "historical mixed-action credits unchanged")
		t.equal(Array(scene.ctx.alive), [true, false], "historical ram owner stays eliminated")
	t.empty(fixture.hits, "mixed base attacks never hit fighters")
	await _dispose(fixture, host)


func _contenders(t: TestHarness, host: Node, reverse: bool) -> void:
	t.test("one-hit base cooldown with two attackers reverse=%s" % reverse)
	var fixture := await _fixture(t, host, reverse, 3)
	var scene: Node = fixture.scene
	for base in scene.controller._bases: base.health = 100.0
	for slot in [1, 2]:
		var body: Fighter = scene.ctx.fighter(slot)
		body.global_position = _base(scene.controller, 0).node.global_position + Vector3(2.0 if slot == 1 else -2.0, 1.3, 0)
		body.facing = Vector3.LEFT if slot == 1 else Vector3.RIGHT
	# Keep the other fighter and spare base inside the arena but outside all attack ranges.
	scene.ctx.fighter(0).global_position = Vector3(0, 1.3, 8)
	_base(scene.controller, 2).node.global_position = Vector3(0, 0, -8)
	_step(scene, -1, [0, ATTACK, ATTACK])
	t.near(scene.controller.base_health(0), 87.0, EPS, "base accepts exactly one authored hit")
	t.equal(Array(scene.ctx.scores), [0, 1, 0], "stable equal-distance slot tie-break credits one attacker")
	t.equal(_base(scene.controller, 0).hits, 1, "one feedback generation only")
	t.greater(float(_base(scene.controller, 0).cooldown), 0.0, "authored cooldown remains active")
	await _dispose(fixture, host)


func _same_base_contenders(t: TestHarness, host: Node, reverse: bool) -> Dictionary:
	var fixture := await _fixture(t, host, reverse, 3)
	var scene: Node = fixture.scene
	for base in scene.controller._bases: base.health = 100.0
	_base(scene.controller, 2).node.global_position = Vector3(0, 0, -8)
	scene.ctx.fighter(0).global_position = Vector3(0, 1.3, 8)
	for slot in [1, 2]:
		var fighter: Fighter = scene.ctx.fighter(slot)
		fighter.global_position = _base(scene.controller, 0).node.global_position + Vector3(3.0 if slot == 1 else -2.0, 1.3, 0)
		fighter.facing = Vector3.LEFT if slot == 1 else Vector3.RIGHT
	return fixture


func _ram_contenders(t: TestHarness, host: Node, reverse: bool, revision: int) -> void:
	t.test("two rams: lower slot farther revision=%d reverse=%s" % [revision, reverse])
	var fixture := await _same_base_contenders(t, host, reverse)
	var scene: Node = fixture.scene
	for slot in [1, 2]: scene.ctx.fighter(slot)._dash_time = 0.2
	_step(scene, revision, [0, 0, 0])
	var selected := 2 if revision == -1 or revision >= 2 else 1
	var expected_scores: Array[int] = [0, 0, 0]
	expected_scores[selected] = 1
	t.equal(Array(scene.ctx.scores), expected_scores, "new batch picks nearest; legacy keeps first ctx slot")
	t.near(scene.controller.base_health(0), 91.0, EPS, "exactly one authored ram damages base")
	t.equal(_base(scene.controller, 0).hits, 1, "one ram feedback generation")
	t.near(float(_base(scene.controller, 0).cooldown), 0.3, EPS, "selected ram starts authored cooldown once")
	for slot in [1, 2]:
		var fighter: Fighter = scene.ctx.fighter(slot)
		t.near(fighter._impulse.length(), 4.0 if slot == selected else 0.0, EPS, "recoil applies only to selected ram")
		t.ok(scene.ctx.fighter(slot) == fixture.originals[slot], "ctx slots unchanged after reversing execution copy")
		fighter._dash_time = 0.0
		fighter._impulse = Vector3.ZERO
		fighter.velocity = Vector3.ZERO
	t.empty(fixture.hits, "no body-to-body melee or ram damage")
	_step(scene, revision, [0, 0, 0])
	t.equal(Array(scene.ctx.scores), expected_scores, "empty next frame never replays a queued ram")
	t.equal(_base(scene.controller, 0).hits, 1, "empty next frame grants no extra hit")
	t.near(float(_base(scene.controller, 0).cooldown), 0.3 - DT, EPS, "cooldown advances exactly once on next frame")
	for slot in [1, 2]:
		t.near(scene.ctx.fighter(slot)._impulse.length(), 0.0, EPS, "empty next frame cannot replay recoil")
	await _dispose(fixture, host)


func _swing_ram_priority(t: TestHarness, host: Node, reverse: bool, revision: int) -> void:
	t.test("swing before closer ram priority revision=%d reverse=%s" % [revision, reverse])
	var fixture := await _same_base_contenders(t, host, reverse)
	var scene: Node = fixture.scene
	scene.ctx.fighter(2)._dash_time = 0.2
	_step(scene, revision, [0, ATTACK, 0])
	t.near(scene.controller.base_health(0), 87.0, EPS, "swing retains authored priority over closer ram")
	t.equal(Array(scene.ctx.scores), [0, 1, 0], "only swing attacker receives a hit credit")
	t.equal(_base(scene.controller, 0).hits, 1, "mixed actions still respect one-hit base cooldown")
	t.near(float(_base(scene.controller, 0).cooldown), 0.3 - DT, EPS, "mixed swing cooldown retains its clock age")
	t.near(scene.ctx.fighter(2)._impulse.length(), 0.0, EPS, "rejected closer ram cannot receive recoil")
	t.empty(fixture.hits, "mixed priority fixture has no fighter hits")
	await _dispose(fixture, host)


func _base_observation(game: Node) -> Array:
	var out: Array = []
	for slot in 2:
		var base := _base(game, slot)
		out.append({"health": base.health, "cooldown": base.cooldown, "hits": base.hits,
			"position": base.node.global_position, "visible": base.node.visible,
			"collision_layer": base.body.collision_layer, "rotation": base.crystal.rotation,
			"height": base.crystal.position.y, "scale": base.crystal.scale})
	return out


func _presentation_only(t: TestHarness, host: Node, reverse: bool) -> void:
	t.test("presentation-only state stable under attacks and ram reverse=%s" % reverse)
	var fixture := await _fixture(t, host, reverse)
	var scene: Node = fixture.scene
	var game: Node = scene.controller
	game.presentation_only = true
	for base in game._bases:
		base.health = 100.0
		base.cooldown = 0.25
		base.hits = 4
	scene.ctx.fighter(0)._dash_time = 0.2
	var before := _base_observation(game)
	_step(scene, 2, [ATTACK, ATTACK])
	t.equal(_base_observation(game), before, "guest observation never advances or damages authoritative bases")
	t.equal(Array(scene.ctx.scores), [0, 0], "guest base callbacks never award points")
	t.equal(Array(scene.ctx.alive), [true, true], "guest base callbacks never eliminate owners")
	t.empty(fixture.hits, "presentation fixture has no direct fighter hits")
	t.ok(not game._action_batch and game._pending_hits.is_empty() and game._pending_eliminations.is_empty(),
		"presentation-only leaves no queued authoritative actions")
	await _dispose(fixture, host)


func _dispose(fixture: Dictionary, host: Node) -> void:
	EventBus.player_hit.disconnect(fixture.on_hit)
	fixture.scene.teardown()
	fixture.scene.queue_free()
	await host.get_tree().process_frame
