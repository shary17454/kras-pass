extends RefCounted
## MutatorSystem: category compatibility, mutual exclusion, and that the
## magnitudes in data/mutators.json actually reach a Fighter's stats.
##
## This system existed in the codebase for a full commit before anything could
## reach it from a menu — these are the tests that should have shipped with it.


func run(t: TestHarness, host: Node) -> void:
	t.suite("mutators")
	await _compatibility(t, host)
	await _magnitudes(t, host)
	await _chaos_schedule(t, host)


func _make_ctx(game_id: String, host: Node) -> Dictionary:
	var cfg := MatchConfig.build(game_id, ["nabta", "sakhra", "fanoos", "ramla"], 0, 0, 5)
	var ctx := MatchContext.new()
	ctx.config = cfg
	ctx.definition = cfg.definition()
	ctx.arena_def = Registry.arena(cfg.arena_id)
	ctx.rng = cfg.make_rng()
	ctx.scores = [0, 0, 0, 0]
	ctx.alive = [true, true, true, true]
	ctx.details = [{}, {}, {}, {}]
	# MatchContext.fighters is a typed Array[Fighter]; assigning an untyped
	# Array to it fails at runtime with an assignment error rather than a
	# compile error — build it typed from the start.
	var fighters: Array[Fighter] = []
	for i in 4:
		var f := Fighter.new()
		host.add_child(f)
		f.setup(i, Registry.characters()[i])
		fighters.append(f)
	ctx.fighters = fighters
	var powerups := PowerUpSystem.new()
	host.add_child(powerups)
	powerups.setup(ctx)
	ctx.powerups = powerups
	return {"ctx": ctx, "fighters": fighters, "powerups": powerups}


func _compatibility(t: TestHarness, host: Node) -> void:
	t.test("mutually exclusive mutators do not both activate")
	var built := _make_ctx("ring_rumble", host)  # push_out: compatible with both gravity mutators
	var ctx: MatchContext = built["ctx"]
	var m := MutatorSystem.new()
	m.setup(ctx, ["low_gravity", "heavy_gravity"], false)
	t.ok(m.active.has("low_gravity"), "the first requested mutator wins the slot")
	t.ok(not m.active.has("heavy_gravity"), "its declared opposite is rejected, not silently layered on top")

	t.test("a mutator outside its declared categories is rejected")
	var collect_ctx: MatchContext = _make_ctx("gem_grab", host)["ctx"]  # category: collect
	var m2 := MutatorSystem.new()
	# double_hazards only lists push_out/survival in data/mutators.json.
	m2.setup(collect_ctx, ["double_hazards"], false)
	t.ok(not m2.active.has("double_hazards"), "gem_grab has no hazards to double, so the mutator is not offered")

	t.test("category-less mutators (e.g. hyper_speed) work in any game")
	var m3 := MutatorSystem.new()
	m3.setup(collect_ctx, ["hyper_speed"], false)
	t.ok(m3.active.has("hyper_speed"), "a mutator with no category list applies everywhere")

	await _cleanup(host, built)


func _magnitudes(t: TestHarness, host: Node) -> void:
	t.test("gravity, speed and size mutators reach the fighter, and reset cleanly")
	var built := _make_ctx("ring_rumble", host)
	var ctx: MatchContext = built["ctx"]
	var fighters: Array = built["fighters"]
	var m := MutatorSystem.new()
	m.setup(ctx, ["low_gravity", "hyper_speed", "tiny"], false)

	var expected_gravity := 0.0
	var expected_speed := 0.0
	var expected_size := 0.0
	for d in Balance.list("mutators", "mutators"):
		match String(d.get("id", "")):
			"low_gravity": expected_gravity = float(d.get("magnitude", 1.0))
			"hyper_speed": expected_speed = float(d.get("magnitude", 1.0))
			"tiny": expected_size = float(d.get("magnitude", 1.0))

	for f in fighters:
		t.near(float(f.mutator["gravity"]), expected_gravity, 0.001, "gravity magnitude reached the fighter")
		t.near(float(f.mutator["speed"]), expected_speed, 0.001, "speed magnitude reached the fighter")
		t.near(float(f.mutator["size"]), expected_size, 0.001, "size magnitude reached the fighter")

	t.test("no_powerups actually disables the power-up spawner")
	var powerups: PowerUpSystem = built["powerups"]
	t.ok(powerups.enabled, "power-ups start enabled for a push-out game")
	var m2 := MutatorSystem.new()
	m2.setup(ctx, ["no_powerups"], false)
	t.ok(not powerups.enabled, "no_powerups turns the spawner off")

	t.test("re-applying with an empty list resets every fighter to baseline")
	var m3 := MutatorSystem.new()
	m3.setup(ctx, [], false)
	for f in fighters:
		t.near(float(f.mutator["gravity"]), 1.0, 0.001, "gravity reset")
		t.near(float(f.mutator["speed"]), 1.0, 0.001, "speed reset")
		t.near(float(f.mutator["size"]), 1.0, 0.001, "size reset")

	await _cleanup(host, built)


func _chaos_schedule(t: TestHarness, host: Node) -> void:
	t.test("chaos mode's mid-round schedule is drawn from the match seed, not wall-clock randomness")
	# Two independent contexts, each with its own freshly-seeded ctx.rng (both
	# built from the same seed in _make_ctx) — NOT one context shared by two
	# systems, which would have the second system continue consuming the first
	# one's already-advanced rng stream and prove nothing about seeding.
	var built_a := _make_ctx("ring_rumble", host)
	var built_b := _make_ctx("ring_rumble", host)
	var a := MutatorSystem.new()
	a.setup(built_a["ctx"], [], true)
	var b := MutatorSystem.new()
	b.setup(built_b["ctx"], [], true)
	t.equal(a._schedule.size(), b._schedule.size(), "two systems built from the same match seed agree on event count")
	var same := true
	for i in a._schedule.size():
		if String(a._schedule[i]["id"]) != String(b._schedule[i]["id"]):
			same = false
			break
	t.ok(same, "and on which mutator fires at each event — a replay has to see the same chaos sequence")

	t.test("chaos swaps the active mutator rather than stacking it")
	if not a._schedule.is_empty():
		var first_id := String(a._schedule[0]["id"])
		var at: float = float(a._schedule[0]["at"])
		a.tick(at + 0.01)
		t.ok(a.active.size() <= 1, "at most one mutator is active at a time under chaos")
		if a.active.size() > 0:
			t.equal(a.active[0], first_id, "and it is the one the schedule named")

	await _cleanup(host, built_a)
	await _cleanup(host, built_b)


func _cleanup(host: Node, built: Dictionary) -> void:
	for f in built["fighters"]:
		if is_instance_valid(f):
			f.queue_free()
	if is_instance_valid(built["powerups"]):
		built["powerups"].queue_free()
	await host.get_tree().process_frame
