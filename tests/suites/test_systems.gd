extends RefCounted
## Input frames, AI profiles, power-up stacking, object pooling and navigation.


func run(t: TestHarness, host: Node) -> void:
	t.suite("systems")
	_input_frames(t)
	_platform(t)
	_ai_profiles(t)
	_pooling(t)
	await _powerups(t, host)
	await _navigation(t, host)


func _input_frames(t: TestHarness) -> void:
	t.test("input frame edge detection")
	var f := InputFrame.new()
	f.bits = InputFrame.Btn.JUMP
	t.ok(f.just_pressed(InputFrame.Btn.JUMP), "a newly set bit is a press")
	t.ok(f.held(InputFrame.Btn.JUMP), "and is held")
	f.prev_bits = f.bits
	t.ok(not f.just_pressed(InputFrame.Btn.JUMP), "a held button is not pressed again")
	f.bits = 0
	t.ok(f.just_released(InputFrame.Btn.JUMP), "clearing the bit is a release")

	t.test("input frames encode and decode losslessly enough for replay")
	var a := InputFrame.new()
	a.move = Vector2(0.5, -1.0)
	a.aim = Vector2(-0.25, 0.75)
	a.bits = InputFrame.Btn.DASH | InputFrame.Btn.ATTACK
	var b := InputFrame.new()
	b.decode(a.encode())
	t.near(b.move.x, 0.5, 0.01, "move x survives quantisation")
	t.near(b.move.y, -1.0, 0.01, "move y survives")
	t.near(b.aim.y, 0.75, 0.01, "aim survives")
	t.equal(b.bits, a.bits, "buttons survive exactly")
	t.equal(a.encode().size(), 5, "five bytes per player per tick")

	t.test("virtual slots accept AI input")
	InputRouter.assign_virtual(0)
	InputRouter.push_virtual(0, Vector2(2.0, 0.0), Vector2.ZERO, InputFrame.Btn.DASH)
	t.equal(InputRouter.source_of(0), InputRouter.Source.VIRTUAL, "slot is virtual")
	t.ok(not InputRouter.is_human(0), "a virtual slot is not human")
	InputRouter.clear_all()


## Safe-area and lifecycle handling. On a desktop the insets are zero, which is
## itself worth asserting: a bug here would silently pad every menu on every
## platform.
func _platform(t: TestHarness) -> void:
	t.test("safe-area insets are sane")
	var insets := Platform.safe_insets()
	for v in [insets.x, insets.y, insets.z, insets.w]:
		t.ok(v >= 0.0, "no negative inset")
	if not Platform.is_mobile:
		t.near(insets.x + insets.y + insets.z + insets.w, 0.0, 0.001,
			"desktop has no safe-area insets")
	var m := Platform.ui_margin(56)
	for side in ["left", "top", "right", "bottom"]:
		t.at_least(int(m[side]), 56, "%s margin is at least the base" % side)

	t.test("backgrounding suspends audio and flushing, resuming restores it")
	var was_suspended := AudioManager.is_suspended()
	AudioManager.set_suspended(true)
	t.ok(AudioManager.is_suspended(), "audio reports suspended")
	AudioManager.set_suspended(false)
	t.ok(not AudioManager.is_suspended(), "and unsuspended")
	AudioManager.set_suspended(was_suspended)

	t.test("a memory warning drains the pools rather than dying")
	Pool.define("warn_probe", func(): return Node3D.new(), 4)
	t.at_least(int(Pool.stats().get("warn_probe", {}).get("free", 0)), 4, "the probe pool is warm")
	Platform._on_memory_warning()
	t.ok(not Pool.stats().has("warn_probe"), "the pool is gone after a memory warning")


func _ai_profiles(t: TestHarness) -> void:
	t.test("four difficulty profiles exist and are ordered")
	var profiles := Balance.list("ai", "profiles")
	t.equal(profiles.size(), 4, "easy, medium, hard, expert")
	var previous_reaction := 99.0
	var previous_accuracy := -1.0
	for p in profiles:
		var reaction := float(p.get("reaction_time", 0.0))
		var accuracy := float(p.get("accuracy", 0.0))
		t.ok(reaction < previous_reaction, "%s reacts faster than the tier below" % p.get("id", "?"))
		t.ok(accuracy > previous_accuracy, "%s aims better than the tier below" % p.get("id", "?"))
		t.ok(reaction > 0.05, "%s is not superhuman" % p.get("id", "?"))
		previous_reaction = reaction
		previous_accuracy = accuracy

	t.test("every mini-game's AI script loads")
	for def in Registry.all_minigames():
		var script: Script = load(def.controller_script)
		var controller = script.new()
		var brain_script = controller.ai_script()
		t.not_null(brain_script, "%s names an AI script" % def.id)
		if brain_script != null:
			var brain = brain_script.new()
			t.ok(brain is AIBrain, "%s's brain extends AIBrain" % def.id)
		controller.free()


func _pooling(t: TestHarness) -> void:
	t.test("object pool reuses instances instead of allocating")
	Pool.drain()
	# GDScript lambdas capture locals by value, so the allocation counter has to
	# be something shared by reference.
	var made := [0]
	Pool.define("test_item", func():
		made[0] += 1
		return Node3D.new())
	var first := Pool.acquire("test_item")
	t.equal(made[0], 1, "first acquire allocates")
	Pool.release("test_item", first)
	var second := Pool.acquire("test_item")
	t.equal(made[0], 1, "second acquire reuses")
	t.equal(second, first, "and hands back the same instance")
	Pool.release("test_item", second)
	var stats := Pool.stats()
	t.equal(int(stats["test_item"]["live"]), 0, "released instances are not counted as live")
	Pool.drain()


func _powerups(t: TestHarness, host: Node) -> void:
	t.test("power-up effects stack, refresh and expire cleanly")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 0, 5)
	var ctx := MatchContext.new()
	ctx.config = cfg
	ctx.definition = cfg.definition()
	ctx.arena_def = Registry.arena(cfg.arena_id)
	ctx.rng = cfg.make_rng()
	ctx.scores = [0, 0, 0, 0]
	ctx.alive = [true, true, true, true]
	ctx.details = [{}, {}, {}, {}]
	var fighter := Fighter.new()
	host.add_child(fighter)
	fighter.setup(0, Registry.character("fanoos"))
	ctx.fighters = [fighter]

	var system := PowerUpSystem.new()
	host.add_child(system)
	system.setup(ctx)
	ctx.powerups = system

	var speed := Registry.powerup("speed")
	system._apply(0, speed)
	t.near(float(fighter.mods["speed"]), speed.magnitude, 0.001, "speed modifier applied")
	system._apply(0, speed)
	t.near(float(fighter.mods["speed"]), speed.magnitude, 0.001,
		"taking the same power-up twice refreshes rather than stacking")

	var shield := Registry.powerup("shield")
	system._apply(0, shield)
	t.near(float(fighter.mods["shield"]), 1.0, 0.001, "shield applied alongside speed")
	var blocked := fighter.take_hit(1, Vector3.RIGHT, 20.0, 10.0)
	t.ok(not blocked, "the shield absorbs the first hit")
	t.near(float(fighter.mods["shield"]), 0.0, 0.001, "and is consumed")

	system._tick_effects(speed.duration + 0.1)
	t.near(float(fighter.mods["speed"]), 1.0, 0.001, "effects expire back to the baseline")

	t.test("clearing effects between rounds leaves no residue")
	system._apply(0, Registry.powerup("double"))
	system.clear_all()
	t.near(float(fighter.mods["points"]), 1.0, 0.001, "point multiplier reset")
	t.equal(system.active_effects_for(0).size(), 0, "no effects remain")

	system.queue_free()
	fighter.queue_free()
	await host.get_tree().process_frame


## Walks every registered screen, confirming each one builds and can get back to
## the main menu. This is the automated form of "no dead ends in navigation".
func _navigation(t: TestHarness, host: Node) -> void:
	t.test("every screen builds and offers a way back")
	var errors_before := Log.error_count()
	for id in SceneRouter.SCREENS.keys():
		if id == "match":
			continue  # covered by the match integration suite
		var script: Script = load(SceneRouter.SCREENS[id])
		t.not_null(script, "screen '%s' has a loadable script" % id)
		if script == null:
			continue
		var node: Node = script.new()
		host.add_child(node)
		node.setup({})
		await host.get_tree().process_frame
		t.ok(node.has_method("go_back"), "screen '%s' implements go_back" % id)
		node.queue_free()
		await host.get_tree().process_frame
	t.equal(Log.error_count() - errors_before, 0, "no screen logged an error while building")

	# Regression: the router's holder used to be attached with call_deferred, so
	# the very first screen opened from Main._ready landed outside the tree and
	# every get_tree() call in it returned null.
	t.test("the router's screen holder is live before the first navigation")
	t.not_null(SceneRouter.holder, "holder exists")
	t.ok(SceneRouter.holder != null and SceneRouter.holder.is_inside_tree(),
		"holder is inside the scene tree")
	await SceneRouter.go_to("main_menu", {}, false, 0.0)
	t.not_null(SceneRouter.current_node, "a screen was opened")
	t.ok(SceneRouter.current_node != null and SceneRouter.current_node.is_inside_tree(),
		"the opened screen is inside the tree")

	t.test("app entry opens the playable main menu without a gated boot screen")
	var main_script: Script = load("res://src/core/main.gd")
	t.not_null(main_script, "main entry script loads")
	if main_script != null:
		var main: Node = main_script.new()
		host.add_child(main)
		await host.get_tree().process_frame
		t.equal(SceneRouter.current_id, "main_menu", "first app frame routes to the main menu")
		t.not_null(SceneRouter.current_node, "main menu node exists after app entry")
		main.queue_free()
		await host.get_tree().process_frame
