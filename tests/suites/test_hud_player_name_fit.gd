extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("HUD complete player names")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		UserSettings.set_value("text_scale", 1.4)
		for game in ["base_siege", "tank_arena"]:
			for characters in [["nabta", "sakhra", "fanoos", "ramla"], ["barq", "mowja", "ghaim", "turs"]]:
				for humans in [1, 4]:
					var cfg := MatchConfig.build(game, characters, humans, 1, 803)
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
						for leader in 4:
							scene.hud._on_lead_changed(leader)
							for frame in 8:
								await host.get_tree().process_frame
							for chip in scene.hud._chips:
								var label: Label = chip.name
								var player: PlayerConfig = cfg.players[chip.slot]
								var expected := player.character().display_name()
								if player.is_human and humans == 1:
									expected = Loc.t("hud.you", {"name": expected})
								t.equal(label.text, player.symbol() + " " + expected, "player identity is not shortened")
								t.ok(not label.clip_text, "name never silently clips")
								var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
								t.ok(width <= label.size.x + 1.0 or label.get_line_count() > 1, "wide name actually wraps to readable lines")
								t.ok(label.get_combined_minimum_size().y <= label.size.y + 1.0, "all name lines receive height")
								t.ok(chip.root.get_global_rect().encloses(label.get_global_rect()), "name remains inside player card")
								t.ok(not label.get_global_rect().intersects(chip.value.get_global_rect()), "name does not overlap score")
						if DisplayServer.get_name() != "headless":
							await RenderingServer.frame_post_draw
							var output := SaveSystem.storage_root.path_join("hud-name-screenshots")
							DirAccess.make_dir_recursive_absolute(output)
							var filename := "%s-%s-%s-%d-%dx%d.png" % [locale, game, characters[0], humans, resolution.x, resolution.y]
							t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual name layout")
					scene.teardown()
					scene.queue_free()
					await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)
