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
		var pooled_chip = hud._chips[0]
		var effect_ids: Array = pooled_chip.effect_labels.keys()
		var count: int = pooled_chip.effects.get_child_count()
		var first: Label = pooled_chip.effect_labels[effect_ids[0]]
		var second: Label = pooled_chip.effect_labels[effect_ids[1]]
		for id in [effect_ids[0], effect_ids[1], effect_ids[0]]:
			scene.powerups._effects = [{"slot": 0, "def": Registry.powerup(id), "remaining": 3.0}]
			hud._refresh_effects(pooled_chip, 0)
			t.equal(pooled_chip.effects.get_child_count(), count, "status changes reuse a bounded registry label set")
			t.ok(pooled_chip.effect_labels[id].visible, "selected status remains visible")
			t.equal(pooled_chip.effect_labels[id].get_theme_color("font_color"), UIKit.adapt(Registry.powerup(id).color), "status replacement preserves its color")
		var visibility_changes := [0]
		first.visibility_changed.connect(func(): visibility_changes[0] += 1)
		hud._refresh_effects(pooled_chip, 0)
		hud._refresh_effects(pooled_chip, 0)
		t.equal(visibility_changes[0], 0, "unchanged status avoids hide/show layout churn")
		scene.powerups._effects.clear()
		hud._refresh_effects(pooled_chip, 0)
		t.ok(not first.visible and not second.visible, "expired statuses hide without deletion")
		t.equal(pooled_chip.effect_labels[effect_ids[0]], first, "reappearing status keeps its label identity")
		var fighter: Fighter = scene.ctx.fighter(0)
		fighter._build_state_fx()
		var state_fx := fighter._state_fx
		fighter._build_state_fx()
		t.equal(fighter._state_fx, state_fx, "preparing status visuals twice is idempotent")
		for child in state_fx.get_children():
			t.ok(not child.visible, "prepared state visuals start hidden")
		for resolution in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(540, 960), Vector2i(1280, 720)]:
			window.size = resolution
			game._set_hunter(-1)
			for slot in [0, 1, 3, 2]:
				game._set_hunter(slot)
				hud.tick(1.0)
				await host.get_tree().process_frame
				await host.get_tree().process_frame
				hud.tick(1.0)
				await host.get_tree().process_frame
				for chip in hud._chips:
					t.ok(not chip.root.get_global_rect().intersects(hud._banner_label.get_global_rect()), "player cards never cover the role banner")
					var bounds: Rect2 = chip.root.get_global_rect()
					t.ok(bounds.position.x >= 0 and bounds.end.x <= host.get_viewport().get_visible_rect().size.x, "player cards remain inside either viewport")
					if resolution.x < resolution.y:
						t.ok(chip.root.get_global_rect().end.y < resolution.y * 0.34, "portrait header leaves the central arena visible")
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
	await _local_names(t, host)
	await _catalog_layout(t, host)


func _local_names(t: TestHarness, host: Node) -> void:
	var window := host.get_tree().root
	var original_size := window.size
	var locale := Loc.locale
	var text_scale = UserSettings.get_value("text_scale")
	UserSettings._values["text_scale"] = 1.6
	for language in ["ar", "en"]:
		Loc.set_locale(language)
		for game_id in ["tag_hunt", "goal_guard", "tank_arena"]:
			var config := MatchConfig.build(game_id, ["fanoos", "nabta", "ramla", "sakhra"], 4, 1, 86)
			for player in config.players:
				player.display_name_override = "اللاعب صاحب الاسم الطويل جدًا / A player with a very long name"
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": config})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
				window.size = resolution
				scene.hud.set_round(0, 3)
				scene.hud.tick(1.0)
				for frame in 4:
					await host.get_tree().process_frame
				for chip in scene.hud._chips:
					var bounds: Rect2 = chip.root.get_global_rect()
					t.ok(bounds.position.x >= 0 and bounds.end.x <= host.get_viewport().get_visible_rect().size.x, "long local names cannot resize player cards off screen")
					t.ok(not chip.name.clip_text, "long names use explicit wrapping and overflow, not silent clipping")
					t.equal(chip.name.tooltip_text, chip.name.text, "full overflow identity remains available")
					t.equal(chip.name.mouse_filter, Control.MOUSE_FILTER_PASS, "name receives tooltip hover without stopping event propagation")
					t.ok(chip.name.get_visible_line_count() <= 3, "legacy oversized name cannot expand indefinitely")
					t.ok(bounds.end.y < host.get_viewport().get_visible_rect().size.y * (0.34 if resolution.x < resolution.y else 0.4), "overflow header leaves arena and controls visible: %s %s end=%s name=%s" % [game_id, resolution, bounds.end.y, chip.name.size])
					t.ok(not chip.name.get_global_rect().intersects(chip.value.get_global_rect()), "overflow name does not cover score")
					t.ok(chip.value.visible and chip.effects.visible, "compact layout retains score and active effects")
					t.equal(chip.name.get_theme_font_size("font_size"), int((14 if resolution.x < resolution.y else 22) * 1.6), "responsive HUD honors larger text setting")
					if resolution.x < resolution.y:
						t.ok(bounds.position.y >= scene.hud._round_label.get_global_rect().end.y, "tournament round label stays above local player cards")
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var output := SaveSystem.storage_root.path_join("hud-custom-name-screenshots")
					DirAccess.make_dir_recursive_absolute(output)
					var filename := "%s-%s-%dx%d.png" % [language, game_id, resolution.x, resolution.y]
					t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual oversized profile name layout")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	Loc.set_locale(locale)
	UserSettings._values["text_scale"] = text_scale
	window.size = original_size


func _catalog_layout(t: TestHarness, host: Node) -> void:
	var window := host.get_tree().root
	var original_size := window.size
	var locale := Loc.locale
	var baseline := host.get_tree().get_node_count()
	for language in ["ar", "en"]:
		Loc.set_locale(language)
		for definition in Registry.minigames():
			var context := MatchContext.new()
			context.config = MatchConfig.build(definition.id, ["fanoos", "nabta", "ramla", "sakhra"], 1, 1, 86)
			context.definition = definition
			context.scores = [123, 24, 3, 1]
			context.alive = [true, true, true, true]
			var arena := Arena.new()
			arena.def = Registry.arena(context.config.arena_id)
			context.arena = arena
			var hud := MatchHUD.new()
			host.add_child(hud)
			hud.setup(context, null)
			hud.set_round(1, 3)
			for resolution in [Vector2i(540, 960), Vector2i(720, 1280), Vector2i(1280, 720)]:
				window.size = resolution
				hud.tick(1.0)
				for frame in 4:
					await host.get_tree().process_frame
				for chip in hud._chips:
					var bounds: Rect2 = chip.root.get_global_rect()
					t.ok(bounds.position.x >= 0 and bounds.end.x <= host.get_viewport().get_visible_rect().size.x, "catalog HUD cards fit: " + definition.id)
					t.ok(not bounds.intersects(hud._timer_label.get_global_rect()), "catalog HUD timer is unobscured: " + definition.id)
					t.ok(chip.value.get_global_rect().end.x <= bounds.end.x, "catalog score remains within its card: " + definition.id)
			hud.queue_free()
			arena.free()
			await host.get_tree().process_frame
			t.equal(host.get_tree().get_node_count(), baseline, "catalog HUD cleanup restores node baseline: " + definition.id)
	Loc.set_locale(locale)
	window.size = original_size
