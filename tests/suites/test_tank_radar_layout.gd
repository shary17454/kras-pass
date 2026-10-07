extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank radar HUD clearance")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for scale in [1.0, 1.4]:
			UserSettings.set_value("text_scale", scale)
			for humans in [1, 4]:
				var cfg := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 702)
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
				var radar: Control
				for layer in scene.get_children():
					if layer is CanvasLayer:
						for child in layer.get_children():
							if child.get_script() == load("res://src/ui/tank_radar.gd"):
								radar = child
				t.ok(radar != null, "tank scene retains its radar")
				for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
					window.size = resolution
					for frame in 12:
						await host.get_tree().process_frame
					if humans > 1:
						t.ok(not radar.visible, "personal views replace the global map without covering the driving region")
						t.equal(scene.vehicle_views.radars.size(), humans, "each driver retains its map")
						for index in humans:
							var map: Control = scene.vehicle_views.radars[index]
							var panel: Control = scene.vehicle_views.panels[index]
							t.ok(Rect2(Vector2.ZERO, panel.size).encloses(Rect2(map.position, map.size * map.scale)), "embedded map stays inside the correct driving view")
						continue
					scene.hud._fit_toasts()
					var rect := radar.get_global_rect()
					t.ok(not rect.intersects(scene.hud._hint_label.get_global_rect()), "radar does not cross the objective after resize in " + locale)
					t.ok(rect.position.y >= scene.hud.occupied_top() + 8.0, "radar clears the actual enlarged HUD")
					t.ok(host.get_viewport().get_visible_rect().encloses(rect), "radar remains inside the viewport")
					scene.hud.show_status_toast("radar-layout", "Connection restored")
					for frame in 12:
						await host.get_tree().process_frame
					scene.hud._fit_toasts()
					t.ok(not radar.get_global_rect().intersects(scene.hud._toast_box.get_global_rect()), "radar clears active status messages")
					t.ok(not radar.get_global_rect().intersects(scene.hud._hint_label.get_global_rect()), "status messages preserve radar/objective clearance")
					if DisplayServer.get_name() != "headless":
						await host.get_tree().create_timer(1.2).timeout
						await RenderingServer.frame_post_draw
						var output := SaveSystem.storage_root.path_join("radar-screenshots")
						DirAccess.make_dir_recursive_absolute(output)
						var filename := "%s-%s-%d-%dx%d.png" % [locale, str(scale), humans, resolution.x, resolution.y]
						t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual rendered radar clearance fixture")
				scene.teardown()
				scene.queue_free()
				await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)
