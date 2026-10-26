extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("menu text remains inside phone width")
	var old_size := host.get_window().size
	var old_locale := Loc.locale
	var old_scale = UserSettings.get_value("text_scale")
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for text_scale in [1.0, 1.4]:
			UserSettings.set_value("text_scale", text_scale)
			for resolution in [Vector2i(360, 780), Vector2i(540, 960), Vector2i(1280, 720)]:
				host.get_window().size = resolution
				for id in ["adventure", "achievements", "replays", "main_menu"]:
					print("MENU_LAYOUT_CASE=%s/%s/%s/%s" % [id, locale, resolution, text_scale])
					t.ok(await SceneRouter.go_to(id, {}, false, 0), "menu opens: " + id)
					for frame in 12:
						await host.get_tree().process_frame
					var screen: Screen = SceneRouter.current_node
					var viewport := host.get_viewport().get_visible_rect()
					_scan(t, screen, viewport)
					var title := screen.find_child("ScreenTitle", true, false) as Label
					t.ok(title != null, "screen has an identifiable title")
					if id == "adventure":
						t.equal(title.get_line_count(), 1, "adventure title does not split its word")
						var picker := screen.find_child("AdventureWorldPicker", true, false) as OptionButton
						t.equal(picker.item_count, Registry.worlds().size(), "all worlds remain selectable")
						for index in picker.item_count:
							var world: Dictionary = Registry.worlds()[index]
							t.equal(picker.is_item_disabled(index), not Progression.is_world_unlocked(String(world.id)), "world locks preserved")
						t.ok(picker.get_global_rect().end.y < viewport.size.y * 0.55, "world picker leaves room for actual stages")
	await SceneRouter.go_to("main_menu", {}, false, 0)
	host.get_window().size = old_size
	Loc.set_locale(old_locale)
	UserSettings.set_value("text_scale", old_scale)


func _scan(t: TestHarness, node: Node, viewport: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var bounds: Rect2 = node.get_global_rect()
		if bounds.size.x > 1.0 and bounds.size.y > 1.0:
			t.ok(bounds.position.x >= viewport.position.x - 1.0 and bounds.end.x <= viewport.end.x + 1.0,
				"no partial horizontal clipping: " + str(node.get_path()))
	if node is Label and node.is_visible_in_tree():
		t.ok(node.get_visible_line_count() == node.get_line_count(), "label does not hide lines: " + str(node.get_path()))
	for child in node.get_children():
		_scan(t, child, viewport)
