extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("Siege HUD text fit")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		UserSettings.set_value("text_scale", 1.6)
		for humans in [1, 4]:
			var cfg := MatchConfig.build("base_siege", ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 802)
			for player in cfg.players:
				if player.is_human:
					player.device_type = 2
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": cfg})
			scene.set_physics_process(false)
			if scene.phase == MatchPhase.P.INTRO:
				scene._set_phase(MatchPhase.P.INSTRUCTIONS)
			scene._set_phase(MatchPhase.P.COUNTDOWN)
			scene._set_phase(MatchPhase.P.PLAYING)
			scene.camera._intro_left = 0.0
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
				window.size = resolution
				for health in [100.0, 99.0, 1.0]:
					for slot in 4:
						scene.controller._bases[slot].health = health
						scene.ctx.scores[slot] = 100
						scene.ctx.alive[slot] = true
					scene.hud.tick(1.0)
					for frame in 8:
						await host.get_tree().process_frame
					for chip in scene.hud._chips:
						var value: Label = chip.value
						var font := value.get_theme_font("font")
						var font_size := value.get_theme_font_size("font_size")
						t.ok(font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= value.size.x + 1.0, "complete siege score fits beside portrait")
						var detail: Label = chip.get("detail")
						t.ok(detail != null, "health has an independent status region")
						if detail != null:
							t.equal(value.text + "\n" + detail.text, scene.controller.hud_value(chip.slot), "all score and health text survives presentation")
							t.ok(not detail.clip_text, "health does not silently clip")
							t.equal(detail.get_line_count(), 1, "percentage stays together on one line at maximum text scale")
							var detail_font := detail.get_theme_font("font")
							var detail_size := detail.get_theme_font_size("font_size")
							t.ok(detail_font.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x <= detail.size.x + 1.0, "full health percentage fits its region")
							t.ok(detail.get_combined_minimum_size().y <= detail.size.y + 1.0, "health has required height")
							t.ok(chip.root.get_global_rect().encloses(detail.get_global_rect()), "health stays inside chip")
					if DisplayServer.get_name() != "headless":
						await host.get_tree().create_timer(0.2).timeout
						await RenderingServer.frame_post_draw
						var output := SaveSystem.storage_root.path_join("siege-hud-screenshots")
						DirAccess.make_dir_recursive_absolute(output)
						var filename := "%s-%d-%dx%d-%d.png" % [locale, humans, resolution.x, resolution.y, int(health)]
						t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual rendered siege HUD")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)
