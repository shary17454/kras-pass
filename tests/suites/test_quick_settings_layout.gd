extends RefCounted

const RESOLUTIONS := [Vector2i(540, 960), Vector2i(1280, 720), Vector2i(390, 844)]
const CAPTIONS := ["quick.opponents", "quick.difficulty", "quick.arena", "quick.rounds", "race.laps", "party.variant"]

func run(t: TestHarness, host: Node) -> void:
	t.suite("quick settings responsive layout")
	var window := host.get_tree().root
	var saved_size := window.size
	var saved_scale_size := window.content_scale_size
	var saved_locale := Loc.locale
	var saved_text_scale = UserSettings.get_value("text_scale")
	var saved_appearance = UserSettings.get_value("appearance")
	var saved_profile := SaveSystem.profile().duplicate(true)
	var saved_progress := Progression._p.duplicate(true)
	var previous_screen := SceneRouter.current_node as Control
	var was_visible := previous_screen.visible if previous_screen != null else false
	var previous_focus := host.get_viewport().gui_get_focus_owner()
	var visual_smoke := OS.get_cmdline_user_args().has("--quick-settings-visual-smoke")
	if previous_screen != null:
		previous_screen.hide()
	UserSettings.set_value("text_scale", 1.0)
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in RESOLUTIONS:
			if visual_smoke and resolution == Vector2i(390, 844):
				continue
			t.test("%s/%dx%d" % [locale, resolution.x, resolution.y])
			window.size = resolution
			await _settle(host)
			var screen = load("res://src/ui/screens/quick_play.gd").new()
			SceneRouter.holder.add_child(screen)
			screen.setup({})
			await _settle(host)
			var form := screen.find_child("FormSettings", true, false) as Control
			var toggle := screen.find_child("PowerupsToggle", true, false) as CheckButton
			if toggle == null:
				for candidate in screen.find_children("*", "CheckButton", true, false):
					toggle = candidate as CheckButton
					break
			if form == null and toggle != null:
				form = _row(toggle).get_parent() as Control
			t.not_null(form, "settings form exists (FormSettings or toggle ancestor)")
			t.not_null(toggle, "compact powerups CheckButton exists")
			var scroll := screen.body.get_parent() as ScrollContainer
			t.not_null(scroll, "screen uses the standard scroll host")
			if scroll != null:
				t.equal(scroll.scroll_vertical, 0, "deferred initial focus does not scroll settings to the bottom")
				t.equal(scroll.scroll_horizontal, 0, "no initial horizontal scrolling")
				t.ok(scroll.get_global_rect().grow(1).encloses(screen._game_option.get_global_rect()), "game selector remains visible at entry")
			if form != null and toggle != null:
				for heading_name in ["ScreenTitle", "GameHeading", "CharacterHeading"]:
					var heading := screen.find_child(heading_name, true, false) as Label
					t.not_null(heading, "screen heading exists: " + heading_name)
					if heading != null:
						_check_label(t, heading)
				for appearance in ["dark", "light"]:
					UserSettings.set_value("appearance", appearance)
					await _settle(host)
					_check_form(t, form)
					_check_powerups(t, form, toggle)
					_check_option(t, screen._game_option)
					await _captures(t, host, scroll, locale + "-" + appearance, resolution)
				if not visual_smoke:
					await _check_longest(t, host, form)
				_check_binding(t, screen, toggle)
				if visual_smoke:
					screen.queue_free()
					await host.get_tree().process_frame
					continue
				# Refresh representative conditional rows without visiting every picker card.
				screen._games = Registry.all_minigames()
				screen._game_option.clear()
				for game in screen._games:
					screen._game_option.add_item(game.display_name())
				for game_id in ["kart_sprint", "tank_arena"]:
					var found := false
					for index in screen._games.size():
						if screen._games[index].id != game_id:
							continue
						found = true
						screen._game_index = index
						screen._refresh_game()
						await _settle(host)
						_check_form(t, form)
						_check_option(t, screen._game_option)
						await _check_longest(t, host, form)
						var arenas: OptionButton = screen._arena_option
						for item in arenas.item_count:
							arenas.select(item)
							arenas.item_selected.emit(item)
							await _settle(host)
							_check_option(t, arenas)
						break
					t.ok(found, "representative conditional game exists: " + game_id)
			screen.queue_free()
			await host.get_tree().process_frame
	window.size = saved_size
	window.content_scale_size = saved_scale_size
	Loc.set_locale(saved_locale)
	UserSettings.set_value("text_scale", saved_text_scale)
	UserSettings.set_value("appearance", saved_appearance)
	SaveSystem.set_profile(saved_profile)
	Progression._p = saved_progress
	if previous_screen != null and is_instance_valid(previous_screen):
		previous_screen.visible = was_visible
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()
	await _settle(host)


func _settle(host: Node) -> void:
	for frame in 30:
		await host.get_tree().process_frame


func _label(node: Node, caption: String) -> Label:
	for candidate in node.find_children("*", "Label", true, false):
		if candidate.text == Loc.t(caption):
			return candidate as Label
	return null


func _row(control: Control) -> Control:
	var parent := control.get_parent() as Control
	if parent != null and parent.get_parent() is MarginContainer:
		return parent.get_parent() as Control
	return parent


func _check_form(t: TestHarness, form: Control) -> void:
	var reference: OptionButton = null
	var visible_count := 0
	for caption in CAPTIONS:
		var label := _label(form, caption)
		t.not_null(label, "translated setting label exists: " + caption)
		if label == null or not label.is_visible_in_tree():
			continue
		var options := label.get_parent().find_children("*", "OptionButton", true, false)
		t.equal(options.size(), 1, "label has one associated option: " + caption)
		if options.size() != 1:
			continue
		var option := options[0] as OptionButton
		visible_count += 1
		_check_label(t, label)
		_check_option(t, option)
		var bounds := option.get_global_rect()
		t.ok(form.get_global_rect().grow(1).encloses(bounds), "option stays inside form: " + caption)
		t.ok(not bounds.intersects(label.get_global_rect()), "option and label do not overlap: " + caption)
		if reference != null:
			var expected := reference.get_global_rect()
			t.near(bounds.position.x, expected.position.x, 1, "option leading bounds are consistent: " + caption)
			t.near(bounds.end.x, expected.end.x, 1, "option trailing bounds are consistent: " + caption)
			t.near(bounds.size.y, expected.size.y, 1, "option heights are consistent: " + caption)
		else:
			reference = option
	t.at_least(visible_count, 4, "core settings remain present")
	if reference != null and form.get_viewport_rect().size.x < form.get_viewport_rect().size.y:
		var start := form.find_child("StartButton", true, false) as Button
		t.not_null(start, "start button exists in the settings form")
		if start != null:
			t.near(start.get_global_rect().position.x, reference.get_global_rect().position.x, 1, "portrait start and fields share their leading edge")
			t.near(start.get_global_rect().end.x, reference.get_global_rect().end.x, 1, "portrait start and fields share their trailing edge")


func _check_label(t: TestHarness, label: Label) -> void:
	t.equal(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "label uses locale-aware leading alignment: " + label.text)
	t.equal(label.is_layout_rtl(), Loc.is_rtl(), "label inherits locale direction: " + label.text)
	t.ok(not label.text.contains("⟦"), "label translation is resolved")
	t.greater(label.size.x, 0, "label has allocated width")
	var glyphs := Rect2()
	for index in label.text.length():
		var bounds := label.get_character_bounds(index)
		if bounds.has_area():
			glyphs = glyphs.merge(bounds) if glyphs.has_area() else bounds
	t.ok(glyphs.has_area(), "label has shaped glyph bounds")
	if glyphs.has_area():
		if Loc.is_rtl():
			t.near(glyphs.end.x, label.size.x, 3, "Arabic text is visibly right-aligned")
		else:
			t.near(glyphs.position.x, 0, 3, "English text is visibly left-aligned")


func _check_longest(t: TestHarness, host: Node, form: Control) -> void:
	for candidate in form.find_children("*", "OptionButton", true, false):
		var option := candidate as OptionButton
		if not option.is_visible_in_tree() or option.item_count == 0:
			continue
		var selected := option.selected
		var height := option.size.y
		var longest := 0
		var widest := -1.0
		var font := option.get_theme_font("font")
		for item in option.item_count:
			var width := font.get_string_size(option.get_item_text(item), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_BODY).x
			if width > widest:
				widest = width
				longest = item
		option.select(longest)
		option.item_selected.emit(longest)
		await _settle(host)
		_check_option(t, option)
		t.near(option.size.y, height, 1, "longest selected label does not change option height")
		option.select(selected)
		option.item_selected.emit(selected)
		await _settle(host)


func _check_option(t: TestHarness, option: OptionButton) -> void:
	t.at_least(option.size.y, 64, "option has a comfortable logical height")
	t.greater(option.size.x, 0, "option has allocated width")
	for state in ["normal", "normal_mirrored", "hover", "hover_mirrored"]:
		var surface := option.get_theme_stylebox(state) as StyleBoxFlat
		t.not_null(surface, "option has a consistent surface: " + state)
		if surface != null:
			t.equal(surface.corner_radius_top_left, 8, "field corner radius stays consistent in RTL and LTR")
	if option.selected < 0:
		t.ok(false, "option has a selected item")
		return
	var text := option.get_item_text(option.selected)
	var font := option.get_theme_font("font")
	var font_size := option.get_theme_font_size("font_size")
	var style := option.get_theme_stylebox("normal")
	var available := option.size.x - style.get_minimum_size().x
	var arrow := option.get_theme_icon("arrow")
	if arrow != null:
		available -= arrow.get_width() + option.get_theme_constant("h_separation")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fits := width <= available + 1
	var explicit_fallback := option.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and option.tooltip_text.contains(text)
	t.ok(fits or explicit_fallback, "selected option text fits or has explicit ellipsis/full tooltip: %s (%.1f/%.1f)" % [text, width, available])


func _check_powerups(t: TestHarness, form: Control, toggle: CheckButton) -> void:
	var label := _label(form, "quick.powerups")
	t.not_null(label, "translated powerups label exists")
	if label == null:
		return
	_check_label(t, label)
	var bounds := toggle.get_global_rect()
	var label_bounds := label.get_global_rect()
	t.at_least(bounds.size.x, 96, "toggle hit target is at least 96 logical units wide")
	t.at_least(bounds.size.y, 64, "toggle hit target is at least 64 logical units tall")
	t.ok(bounds.size.x < _row(toggle).size.x * 0.5, "toggle is compact, not a full-width field")
	t.ok(form.get_global_rect().grow(1).encloses(bounds), "toggle stays inside the settings form")
	t.near(bounds.get_center().y, label_bounds.get_center().y, 1, "powerups label and toggle share a row in both orientations")
	t.ok(not bounds.intersects(label_bounds), "powerups label does not overlap the hit target")
	if Loc.is_rtl():
		t.ok(label_bounds.position.x >= bounds.end.x, "Arabic powerups caption is to the right")
	else:
		t.ok(label_bounds.end.x <= bounds.position.x, "English powerups caption is to the left")
	t.equal(toggle.focus_mode, Control.FOCUS_ALL, "toggle remains keyboard/gamepad accessible")


func _check_binding(t: TestHarness, screen: Control, toggle: CheckButton) -> void:
	var start: Button = null
	for candidate in screen.find_children("*", "Button", true, false):
		if candidate.text == Loc.t("quick.start"):
			start = candidate as Button
			break
	t.not_null(start, "translated start action exists")
	if start == null:
		return
	for enabled in [false, true]:
		toggle.button_pressed = enabled
		t.equal(screen._powerups, enabled, "toggle signal updates the screen state")
		var config: MatchConfig = screen._build_match_config()
		t.equal(config.allow_powerups, enabled, "match configuration uses the current powerups value")
		t.equal(config.minigame_id, screen._games[screen._game_index].id, "selected minigame remains unchanged")
		t.at_least(config.players.size(), 1, "match retains its local player")


func _captures(t: TestHarness, host: Node, scroll: ScrollContainer, locale: String, resolution: Vector2i) -> void:
	if scroll == null or DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--quick-settings-captures"):
		return
	if resolution == Vector2i(390, 844):
		return
	var output := SaveSystem.storage_root.path_join("screenshots")
	t.equal(DirAccess.make_dir_recursive_absolute(output), OK, "create isolated screenshot directory")
	for position in ["top", "settings-bottom"]:
		scroll.scroll_vertical = 0 if position == "top" else 100000
		await _settle(host)
		await RenderingServer.frame_post_draw
		var path := output.path_join("quick-settings-%s-%dx%d-%s.png" % [locale, resolution.x, resolution.y, position])
		t.equal(host.get_viewport().get_texture().get_image().save_png(path), OK, "capture " + path)
	scroll.scroll_vertical = 0
	await _settle(host)
