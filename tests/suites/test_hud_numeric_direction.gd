extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("HUD numeric direction")
	t.test("fractions and localized player names")
	var language := Loc.locale
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("goal_guard", ["nabta", "sakhra", "fanoos", "ramla"], 1, 1, 250925)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		scene.ctx.scores[0] = 11
		scene.hud.tick(1.0)
		var chip: Dictionary = scene.hud._chips[0]
		t.equal(chip.value.text, "11 / 12", "current score precedes its maximum in the underlying value: " + locale)
		t.equal(chip.value.text_direction, Control.TEXT_DIRECTION_LTR, "numeric fractions retain their order in either locale: " + locale)
		t.equal(chip.name.text_direction, Control.TEXT_DIRECTION_RTL if locale == "ar" else Control.TEXT_DIRECTION_LTR, "player names keep their localized direction: " + locale)
		t.equal(chip.value.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT if locale == "ar" else HORIZONTAL_ALIGNMENT_LEFT, "numeric direction does not change localized alignment: " + locale)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	Loc.set_locale(language)
