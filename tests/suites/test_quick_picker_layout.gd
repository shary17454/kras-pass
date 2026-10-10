extends RefCounted

const LayoutProbe = preload("res://tests/layout_check.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("quick picker layout")
	t.test("all game and character cards remain inside their layout allocation")
	var original_locale := Loc.locale
	var window := host.get_tree().root
	var original_size := window.size
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in LayoutProbe.RESOLUTIONS:
			window.size = resolution
			t.ok(await SceneRouter.go_to("quick_play", {}, false, 0), "quick play opens")
			var screen := SceneRouter.current_node
			screen._games = Registry.all_minigames()
			screen._characters = Registry.characters()
			screen._game_option.clear()
			for game in screen._games:
				screen._game_option.add_item(game.display_name())
			for index in screen._games.size():
				screen._game_index = index
				screen._refresh_game()
				for frame in 6:
					await host.get_tree().process_frame
				var issues := LayoutProbe.picker_issues(screen)
				t.ok(issues.is_empty(), "%s/%s/%s: %s" % [locale, resolution, screen._games[index].id, issues])
			for index in screen._characters.size():
				screen._character_index = index
				screen._refresh_character()
				for frame in 6:
					await host.get_tree().process_frame
				var issues := LayoutProbe.picker_issues(screen)
				t.ok(issues.is_empty(), "%s/%s/%s: %s" % [locale, resolution, screen._characters[index].id, issues])
	window.size = original_size
	Loc.set_locale(original_locale)
	await SceneRouter.go_to("main_menu", {}, false, 0)
