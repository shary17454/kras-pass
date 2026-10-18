extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("Round announcement fit")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	UserSettings.set_value("text_scale", 1.6)
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		var texts: Array[String] = []
		for definition in Registry.all_minigames():
			texts.append(definition.display_name())
		t.ok(texts.size() >= 39, "catalogue announcement coverage includes bosses and 39-plus games")
		texts.append_array([Loc.t("hud.go"), Loc.t("hud.finish"), Loc.t("hud.sudden_death"), "3", "10"])
		for game in ["base_siege", "tank_arena"]:
			for humans in [1, 4]:
				var cfg := MatchConfig.build(game, ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 804)
				for player in cfg.players:
					if player.is_human:
						player.device_type = 2
				var scene: Node = load("res://src/match/match_scene.gd").new()
				host.add_child(scene)
				scene.setup({"config": cfg})
				scene.set_physics_process(false)
				for fighter in scene.ctx.fighters:
					fighter.set_physics_process(false)
				for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
					window.size = resolution
					for frame in 8:
						await host.get_tree().process_frame
					for text in texts:
						var previous: Tween = scene.hud.get("_announcement_tween")
						scene.hud.announce(text, UIKit.ACCENT, 0.75, text in ["3", "10"])
						var label: Label = scene.hud._centre_label
						var initial := label.get_global_rect()
						var initial_view := host.get_viewport().get_visible_rect().size
						var initial_bottom := TouchSource.party_region(initial_view, 0, humans).position.y if humans > 1 else initial_view.y * 0.76
						t.ok(initial.position.x >= 0 and initial.end.x <= initial_view.x, "first animation frame stays inside viewport")
						t.ok(initial.position.y >= scene.hud.occupied_top() and initial.end.y <= initial_bottom, "first animation frame leaves HUD and controls clear: %s %s %d %s '%s' rect=%s lower=%s" % [locale, game, humans, resolution, text, initial, initial_bottom])
						if DisplayServer.get_name() != "headless":
							t.ok(previous == null or not previous.is_valid(), "replacement announcement cancels predecessor animation")
						for frame in 3:
							await host.get_tree().process_frame
						var viewport_size := host.get_viewport().get_visible_rect().size
						var lower := TouchSource.party_region(viewport_size, 0, humans).position.y if humans > 1 else viewport_size.y * 0.76
						var rect := label.get_global_rect()
						t.equal(label.text, text, "announcement retains full localized text")
						t.ok(not label.clip_text and label.get_visible_line_count() == label.get_line_count(), "no announcement line is hidden")
						var width := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
						t.ok(width <= label.size.x + 1.0 or label.get_line_count() > 1, "long announcement wraps rather than leaving viewport")
						t.ok(label.get_combined_minimum_size().y <= label.size.y + 1.0, "all announcement lines fit vertically")
						t.ok(rect.position.x >= 0 and rect.end.x <= viewport_size.x, "animated announcement stays inside viewport width")
						t.ok(rect.position.y >= scene.hud.occupied_top(), "animated announcement leaves HUD unobscured")
						t.ok(rect.end.y <= lower, "animated announcement leaves touch controls unobscured: %s %s %d %s '%s' rect=%s lower=%s" % [locale, game, humans, resolution, text, rect, lower])
						if DisplayServer.get_name() != "headless" and (text == cfg.definition().display_name() or text == Loc.t("hud.go") or text == "3"):
							await RenderingServer.frame_post_draw
							var output := SaveSystem.storage_root.path_join("round-announcement-screenshots")
							DirAccess.make_dir_recursive_absolute(output)
							var kind := "title" if text == cfg.definition().display_name() else "countdown" if text == "3" else "go"
							var filename := "%s-%s-%d-%dx%d-%s.png" % [locale, game, humans, resolution.x, resolution.y, kind]
							t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual early announcement animation")
				scene.teardown()
				scene.queue_free()
				await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)
