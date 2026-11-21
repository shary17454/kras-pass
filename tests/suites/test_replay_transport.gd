extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay transport responsive layout")
	var window := host.get_tree().root
	var original_size := window.size
	var original_locale := Loc.locale
	var original_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		UserSettings.set_value("text_scale", 1.4)
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			window.size = resolution
			var screen: Control = load("res://src/ui/screens/replay_player.gd").new()
			var recording := ReplayData.new()
			recording.minigame_id = "sweeper_storm"
			for kind in ["narrow_win", "late_swing", "comeback", "early_exit", "multi_knockout", "big_hit"]:
				recording.highlights.append({"tick": 0, "kind": kind, "slot": 0, "detail": ""})
			screen.replay = recording
			var column := VBoxContainer.new()
			column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.add_child(column)
			var panel: Control = screen._transport()
			column.add_child(panel)
			for frame in 8:
				await host.get_tree().process_frame
			var viewport := host.get_viewport().get_visible_rect()
			t.ok(viewport.encloses(panel.get_global_rect()), "%s %s transport remains in viewport" % [locale, resolution])
			var buttons := _buttons(panel)
			t.equal(buttons.size(), 12, "all transport and highlight controls remain available")
			for button in buttons:
				t.ok(panel.get_global_rect().encloses(button.get_global_rect()), "control stays inside transport: " + button.text)
				for other in buttons:
					if other != button:
						t.ok(not button.get_global_rect().intersects(other.get_global_rect()), "controls do not overlap")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var output := SaveSystem.storage_root.path_join("replay-transport-screenshots")
				DirAccess.make_dir_recursive_absolute(output)
				var filename := "%s-%dx%d.png" % [locale, resolution.x, resolution.y]
				t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save rendered transport")
			column.queue_free()
			screen.free()
			await host.get_tree().process_frame
	window.size = original_size
	Loc.set_locale(original_locale)
	UserSettings.set_value("text_scale", original_scale)


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result
