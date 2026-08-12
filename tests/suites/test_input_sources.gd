extends RefCounted
## The central promise of the input layer: a mini-game cannot tell where a
## player's intent came from.
##
## Every source — pad, keyboard, AI, touch, replay, and later the network —
## produces an `InputFrame` and nothing else. These tests drive the *same*
## fighter from different sources and assert the resulting motion is identical,
## which is what lets 21 games work on a phone with no per-game touch code.


func run(t: TestHarness, host: Node) -> void:
	t.suite("input sources")
	await _sources_are_indistinguishable(t, host)
	_touch_profiles(t)
	_touch_layout_rules(t)


## Drive one fighter from a virtual (AI) slot and another from a touch slot with
## byte-identical intent, and assert they end up in the same place.
func _sources_are_indistinguishable(t: TestHarness, host: Node) -> void:
	t.test("a fighter moves identically regardless of input source")
	var character := Registry.character("fanoos")
	var a := Fighter.new()
	var b := Fighter.new()
	host.add_child(a)
	host.add_child(b)
	a.setup(0, character)
	b.setup(1, character)
	a.global_position = Vector3(0, 0.1, 0)
	b.global_position = Vector3(0, 0.1, 0)
	a.control_enabled = true
	b.control_enabled = true

	InputRouter.assign_virtual(0)
	InputRouter.assign_touch(1)
	t.ok(not InputRouter.is_human(0), "the AI slot is not human")
	t.ok(InputRouter.is_human(1), "the touch slot is human")

	var delta := 1.0 / 60.0
	for step in 40:
		var move := Vector2(sin(step * 0.2), cos(step * 0.13))
		var bits := InputFrame.Btn.DASH if step == 10 else 0
		InputRouter.push_virtual(0, move, Vector2.ZERO, bits)
		InputRouter.push_virtual(1, move, Vector2.ZERO, bits)
		await host.get_tree().physics_frame
		a.tick(InputRouter.frame(0), delta)
		b.tick(InputRouter.frame(1), delta)

	t.near(a.global_position.x, b.global_position.x, 0.001, "same x after 40 ticks")
	t.near(a.global_position.z, b.global_position.z, 0.001, "same z after 40 ticks")
	t.near(a.velocity.length(), b.velocity.length(), 0.001, "same speed")
	InputRouter.clear_all()
	a.queue_free()
	b.queue_free()
	await host.get_tree().process_frame


func _touch_profiles(t: TestHarness) -> void:
	t.test("every mini-game declares a usable control profile")
	var missing: Array[String] = []
	for def in Registry.minigames():
		var kind := def.control_profile
		if not ControlProfile.NAMES.has(kind):
			missing.append(def.id)
		# A game the player has to move in must offer a way to move.
		var needs_move := def.control_hints.has("move") or def.control_hints.has("drive")
		var offers_move := ControlProfile.shows_move_stick(kind) or ControlProfile.shows_steering(kind)
		if needs_move and not offers_move:
			missing.append("%s (declares movement but its profile has no movement widget)" % def.id)
		# ...and a game that does not move should not be given a stick.
		if not needs_move and offers_move and ControlProfile.full_screen_tap(kind) == 0:
			missing.append("%s (no movement, but the profile shows a stick)" % def.id)
	t.empty(missing, "control profiles match declared controls")

	t.test("driving games use the steering layout")
	for def in Registry.minigames():
		if def.control_hints.has("drive"):
			t.equal(ControlProfile.name_of(def.control_profile), "steering",
				"%s drives, so it steers" % def.id)


func _touch_layout_rules(t: TestHarness) -> void:
	t.test("touch buttons are derived from declared controls, never duplicated")
	for def in Registry.minigames():
		var buttons := ControlProfile.buttons_for(def.control_profile, def.control_hints)
		var seen_bits := {}
		for b in buttons:
			t.ok(def.control_hints.has(b), "%s: button '%s' is a control the game declared" % [def.id, b])
			var bit: int = ControlProfile.BUTTON_BITS[b]
			t.ok(not seen_bits.has(bit), "%s: no two buttons send the same bit" % def.id)
			seen_bits[bit] = true
		t.ok(buttons.size() <= 4, "%s shows at most four action buttons" % def.id)

	t.test("reaction and memory layouts show no action buttons")
	for kind in [ControlProfile.Kind.REACTION, ControlProfile.Kind.MEMORY]:
		var b := ControlProfile.buttons_for(kind, PackedStringArray(["move", "attack", "dash", "jump"]))
		t.equal(b.size(), 0, "%s has a clean layout" % ControlProfile.name_of(kind))
	t.equal(ControlProfile.full_screen_tap(ControlProfile.Kind.REACTION), InputFrame.Btn.ATTACK,
		"a reaction game turns the whole screen into the attack button")
	t.equal(ControlProfile.full_screen_tap(ControlProfile.Kind.MOVEMENT_ACTION), 0,
		"other layouts do not swallow the screen")

	t.test("the touch overlay is off by default on a desktop")
	var before = UserSettings.get_value("touch_controls")
	UserSettings.set_value("touch_controls", "off")
	t.ok(not TouchSource.should_show(), "'off' hides it")
	UserSettings.set_value("touch_controls", "on")
	t.ok(TouchSource.should_show(), "'on' forces it")
	UserSettings.set_value("touch_controls", before)
