extends RefCounted
## Exercise navigation through the production router, not detached screens.


func run(t: TestHarness, host: Node) -> void:
	t.suite("routed navigation")
	var language := Loc.locale
	var window := host.get_tree().root
	var original_size := window.size
	var errors_before := Log.error_count()
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for cycle in 2:
			window.size = Vector2i(540, 960) if cycle == 0 else Vector2i(1280, 720)
			for id in SceneRouter.SCREENS:
				if id in ["main_menu", "match"]:
					continue
				SceneRouter.clear_stack()
				t.ok(await SceneRouter.go_to("main_menu", {}, false, 0.0), "prepare menu for %s/%s/%d" % [locale, id, cycle])
				await host.get_tree().process_frame
				var menu := weakref(SceneRouter.current_node)
				t.ok(await SceneRouter.go_to(id, {}, true, 0.0), "route opens %s/%s/%d" % [locale, id, cycle])
				await host.get_tree().process_frame
				t.equal(menu.get_ref(), null, "previous menu released for %s" % id)
				t.equal(SceneRouter.current_id, id, "router installs requested screen %s" % id)
				t.equal(SceneRouter.holder.get_child_count(), 1, "one screen after opening %s" % id)
				var screen := weakref(SceneRouter.current_node)
				if id == "boot":
					await host.get_tree().create_timer(0.4).timeout
				var visited: Array[String] = []
				while SceneRouter.current_id != "main_menu" and visited.size() < SceneRouter.SCREENS.size():
					var departing := SceneRouter.current_id
					if visited.has(departing):
						break
					visited.append(departing)
					var departing_node := weakref(SceneRouter.current_node)
					SceneRouter.current_node.go_back()
					var deadline := Time.get_ticks_msec() + 5000
					while SceneRouter._busy and Time.get_ticks_msec() < deadline:
						await host.get_tree().process_frame
					await host.get_tree().process_frame
					t.equal(departing_node.get_ref(), null, "back releases %s" % departing)
					t.equal(SceneRouter.holder.get_child_count(), 1, "one screen at each back hop from %s" % departing)
					if SceneRouter._busy:
						break
				t.equal(SceneRouter.current_id, "main_menu", "real back action reaches menu from %s" % id)
				t.ok(not SceneRouter._busy, "router unlocked after leaving %s" % id)
				t.equal(screen.get_ref(), null, "departed screen released for %s" % id)
				t.equal(SceneRouter.holder.get_child_count(), 1, "no duplicate screens after leaving %s" % id)
				if SceneRouter._busy or SceneRouter.current_id != "main_menu":
					window.size = original_size
					Loc.set_locale(language)
					return
	window.size = original_size
	Loc.set_locale(language)
	SceneRouter.clear_stack()
	t.equal(Log.error_count(), errors_before, "all routed menus build and return without logged errors")
