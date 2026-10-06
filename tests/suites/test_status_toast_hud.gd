extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("live status toast HUD")
	var locale := Loc.locale
	var window := host.get_tree().root
	var original_size := window.size
	for language in ["ar", "en"]:
		Loc.set_locale(language)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("tag_hunt", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var game = scene.controller
		var hud = scene.hud
		for resolution in [Vector2i(1280, 720), Vector2i(720, 1280)]:
			window.size = resolution
			game._set_hunter(-1)
			for slot in [0, 1, 3, 2]:
				game._set_hunter(slot)
				hud.tick(1.0)
				await host.get_tree().process_frame
				await host.get_tree().process_frame
				hud.tick(1.0)
				await host.get_tree().process_frame
				t.equal(hud._status_toasts.size(), 1, "rapid role changes retain one live message")
				var card: Control = hud._status_toasts["tag.hunter"].card
				t.equal(card.get_child(0).text, "☄  " + game.hud_banner(), "toast and live banner identify the same hunter")
				t.ok(card.get_global_rect().position.y >= hud.occupied_top(), "toast stays below clock, banner and player chips")
				if resolution.x < resolution.y:
					t.ok(hud._hint_label.get_global_rect().position.y >= card.get_global_rect().end.y, "portrait objective stays below the notification")
				var previous: Control = card
				game._set_hunter(slot)
				t.equal(hud._status_toasts["tag.hunter"].card, previous, "identical network snapshots do not rebuild the message")
			game._set_hunter(-1)
			t.equal(hud._status_toasts.size(), 0, "clearing role clears transient status immediately")
			hud.show_status_toast("other", "A long notification that wraps inside the safe viewport width", "")
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			hud.tick(1.0)
			await host.get_tree().process_frame
			var bounds: Rect2 = hud._status_toasts.other.card.get_global_rect()
			t.ok(bounds.position.x >= 0 and bounds.end.x <= host.get_viewport().get_visible_rect().size.x, "LTR and RTL notifications stay inside viewport")
			hud.show_status_toast("other", "", "")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	Loc.set_locale(locale)
	window.size = original_size
