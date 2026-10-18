extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("daily challenge responsive layout")
	var window := host.get_tree().root
	var previous_size := window.size
	var previous_locale := Loc.locale
	var previous_scale = UserSettings.get_value("text_scale")
	UserSettings.set_value("text_scale", 1.4)
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			window.size = resolution
			var screen: Control = load("res://src/ui/screens/daily_screen.gd").new()
			host.add_child(screen)
			screen.setup({})
			for frame in 30:
				await host.get_tree().process_frame
			var viewport := host.get_viewport().get_visible_rect()
			t.ok(viewport.encloses(screen.first_focus.get_global_rect()), "start remains visible without scrolling")
			_scan(t, screen, viewport)
			var scroll: ScrollContainer = screen.body.get_parent()
			scroll.scroll_vertical = 100000
			await host.get_tree().process_frame
			t.ok(viewport.encloses(screen.first_focus.get_global_rect()), "start remains visible after scrolling")
			if DisplayServer.get_name() != "headless":
				scroll.scroll_vertical = 0
				await RenderingServer.frame_post_draw
				var output := SaveSystem.storage_root.path_join("daily-layout-screenshots")
				DirAccess.make_dir_recursive_absolute(output)
				t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [locale, resolution.x, resolution.y])), OK, "capture daily layout")
			screen.queue_free()
			await host.get_tree().process_frame
	window.size = previous_size
	Loc.set_locale(previous_locale)
	UserSettings.set_value("text_scale", previous_scale)


func _scan(t: TestHarness, node: Node, viewport: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var bounds: Rect2 = node.get_global_rect()
		t.ok(bounds.position.x >= viewport.position.x - 1.0 and bounds.end.x <= viewport.end.x + 1.0, "no horizontal overflow: " + str(node.get_path()))
	if node is Label:
		t.ok(not String(node.text).contains("⟦"), "all labels are localized")
	for child in node.get_children():
		_scan(t, child, viewport)
