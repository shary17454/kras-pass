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
		scene.hud.set_round(0, 3)
		t.equal(scene.hud._round_label.text, "الجولة 1 من 3" if locale == "ar" else "Round 1 / 3", "round progress is unambiguous in its localized sentence: " + locale)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	Loc.set_locale(language)
	await _physical_slot_order(t, host)


func _physical_slot_order(t: TestHarness, host: Node) -> void:
	t.suite("HUD slots follow controller order independently of text language")
	var language := Loc.locale
	var old_size := host.get_window().size
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
			host.get_window().size = resolution
			await host.get_tree().process_frame
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			var cfg := MatchConfig.build("goal_guard", ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 510186)
			for player in cfg.players:
				player.device_type = 2
			scene.setup({"config": cfg})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			for frame in 4:
				await host.get_tree().process_frame
			for slot in 4:
				var chip: Dictionary = scene.hud._chips[slot]
				t.equal(chip.slot, slot, "slot identity is unchanged by localization")
				t.equal(chip.name.text_direction, Control.TEXT_DIRECTION_RTL if locale == "ar" else Control.TEXT_DIRECTION_LTR,
					"card text keeps the selected language direction")
				if slot > 0:
					var previous: Control = scene.hud._chips[slot - 1].root
					t.ok(previous.get_global_rect().position.x < chip.root.get_global_rect().position.x,
						"%s/%s player %d follows the previous physical slot" % [locale, resolution, slot + 1])
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	host.get_window().size = old_size
	Loc.set_locale(language)
	await host.get_tree().process_frame
