extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("boss health HUD")
	var locale := Loc.locale
	var window := host.get_tree().root
	var original_size := window.size
	for game_id in ["boss_forge", "boss_colossus", "boss_dreadnought", "boss_sovereign"]:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(game_id, ["nabta", "sakhra", "barq", "turs"], 0, 1, 188)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		for language in ["ar", "en"]:
			Loc.set_locale(language)
			scene.controller.boss_health = scene.controller.boss_max_health * 0.5
			var banner: String = scene.controller.hud_banner()
			t.ok(not banner.contains("█") and not banner.contains("░"), "health does not depend on block font glyphs: " + game_id + "/" + language)
			t.ok(banner.contains("50%"), "health remains numerically readable: " + language)
			t.equal(banner, Loc.t("hud.boss_health", {"value": 50}), "boss caption uses the selected localization table")
			var meter = scene.hud.get("_boss_meter")
			t.ok(meter is ProgressBar, "shared HUD owns a real health meter: " + game_id)
			if not meter is ProgressBar:
				continue
			for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
				window.size = resolution
				scene.hud.set_round(0, 3)
				scene.hud.tick(1.0)
				await host.get_tree().process_frame
				await host.get_tree().process_frame
				t.ok(meter.visible, "boss meter is visible in either orientation")
				t.near(meter.value, 0.5, 0.00001, "meter reads authoritative health fraction")
				t.ok(not meter.show_percentage, "percentage is not duplicated inside the small meter")
				if resolution.x < resolution.y:
					t.ok(scene.hud.occupied_top() < resolution.y * 0.35, "portrait boss HUD leaves the majority of the screen for gameplay")
					for chip in scene.hud._chips:
						t.ok(chip.root.get_global_rect().position.y >= meter.get_global_rect().end.y, "portrait player chips do not overlap health meter")
			for fraction in [1.0, 0.0, 2.0, -0.5]:
				scene.controller.boss_health = scene.controller.boss_max_health * fraction
				scene.hud.tick(1.0)
				t.near(meter.value, clampf(fraction, 0.0, 1.0), 0.00001, "health meter bounds full, empty and invalid range values")
		scene.controller.boss_health = NAN
		scene.hud.tick(1.0)
		t.ok(not scene.hud._boss_meter.visible, "invalid health does not display a misleading meter")
		t.equal(scene.hud._banner_label.text, "", "invalid health does not display a misleading percentage")
		var ordinary := MiniGameController.new()
		ordinary.ctx = scene.ctx
		ordinary.def = scene.ctx.definition
		scene.hud.controller = ordinary
		scene.hud.tick(1.0)
		t.ok(not scene.hud._boss_meter.visible, "ordinary minigames do not inherit a boss meter")
		scene.hud.controller = scene.controller
		ordinary.free()
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	Loc.set_locale(locale)
	window.size = original_size
