extends Screen
## Profile: completion, currency, favourites and the realm-by-realm breakdown.


func build() -> void:
	title(Loc.t("profile.title"))
	var profiles := SaveSystem.profile_ids()
	var names: Array = []
	for id in profiles:
		var name := String(SaveSystem.profile_meta(id)["name"])
		names.append(Loc.t(name) if Loc.has(name) else name)
	var select := UIKit.option(names, maxi(0, profiles.find(SaveSystem.active_profile_id())))
	select.item_selected.connect(func(i):
		SaveSystem.switch_profile(profiles[i])
		SceneRouter.go_to("profile", {}, false))
	body.add_child(UIKit.row(Loc.t("party.local_profile"), select))
	var new_profile := UIKit.hbox(12)
	var name_field := LineEdit.new()
	name_field.max_length = 24
	name_field.custom_minimum_size.y = 64
	name_field.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	name_field.placeholder_text = Loc.t("party.player_name")
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_profile.add_child(name_field)
	var create := UIKit.button(Loc.t("party.create_profile"), UIKit.SIZE_SMALL)
	create.pressed.connect(func():
		var value := name_field.text.strip_edges()
		if not value.is_empty() and SaveSystem.profile_ids().size() < 16:
			SaveSystem.switch_profile(SaveSystem.create_profile(value))
			SceneRouter.go_to("profile", {}, false))
	new_profile.add_child(create)
	body.add_child(new_profile)
	_add_preferences()
	if AppleAccount.available():
		var account_button := UIKit.button(Loc.t("account.title"), UIKit.SIZE_SMALL)
		account_button.pressed.connect(func(): SceneRouter.go_to("account"))
		header.add_child(account_button)
	body.add_child(UIKit.label(Loc.t("title.%s.name" % Progression.selected_title()), UIKit.SIZE_BODY, UIKit.ACCENT_2, true))
	var completion := Progression.completion_percent()
	body.add_child(Widgets.progress_row(Loc.t("profile.completion"), "%.1f%%" % completion, completion / 100.0, UIKit.ACCENT))

	var strip := UIKit.adaptive_columns(18)
	body.add_child(strip)
	strip.add_child(_tile("🏆", Loc.t("profile.trophies"), str(Progression.trophies())))
	strip.add_child(_tile("💎", Loc.t("profile.gems"), str(Progression.gems())))
	strip.add_child(_tile("🥇", Loc.t("stats.wins"), str(Stats.total_wins())))
	strip.add_child(_tile("🎪", Loc.t("stats.tournaments"), str(Progression.tournaments_won())))
	strip.add_child(_tile("🏅", Loc.t("menu.achievements"), "%d/%d" % [Achievements.earned_count(), Achievements.total_count()]))

	body.add_child(UIKit.heading(Loc.t("adventure.title")))
	for w in Registry.worlds():
		var wid := String(w.get("id", ""))
		var prog := Progression.world_progress(wid)
		var total := maxi(1, int(prog["total"]))
		var locked := not Progression.is_world_unlocked(wid)
		body.add_child(Widgets.progress_row(
			("🔒 " if locked else "") + Loc.t(String(w.get("name_key", ""))),
			"%d/%d  ★%d" % [prog["cleared"], prog["total"], prog["stars"]],
			float(prog["cleared"]) / float(total),
			CharacterData._color(w.get("color", "#ffffff"))))

	var row := UIKit.adaptive_columns(14)
	body.add_child(row)
	for entry in [["menu.stats", "stats"], ["menu.achievements", "achievements"], ["menu.rewards", "rewards"],
			["menu.customize", "customize"]]:
		var b := UIKit.button(Loc.t(String(entry[0])), UIKit.SIZE_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): SceneRouter.go_to(String(entry[1])))
		row.add_child(b)
		if first_focus == null:
			first_focus = b


func _tile(glyph: String, label: String, value: String) -> Control:
	var card := UIKit.panel(UIKit.PANEL, 14)
	card.custom_minimum_size = Vector2(200, 120)
	var v := UIKit.vbox(2)
	card.add_child(v)
	v.add_child(UIKit.centered(glyph, UIKit.SIZE_HEADING))
	v.add_child(UIKit.centered(value, UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	v.add_child(UIKit.centered(label, UIKit.SIZE_TINY, UIKit.dim_color()))
	return card


func _add_preferences() -> void:
	var characters := Progression.playable_characters()
	var names: Array = []
	var selected := 0
	for i in characters.size():
		names.append(characters[i].display_name())
		if characters[i].id == Progression.last_character():
			selected = i
	var favorite := UIKit.option(names, selected)
	favorite.item_selected.connect(func(i):
		Progression.set_last_character(characters[i].id)
		SaveSystem.flush())
	body.add_child(UIKit.row(Loc.t("party.favorite_character"), favorite))
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 12)
	swatches.add_theme_constant_override("v_separation", 12)
	var group := ButtonGroup.new()
	for palette in Registry.palettes():
		var id := String(palette.get("id", ""))
		if not Progression.is_palette_unlocked(id):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = id == Progression.selected_palette()
		button.tooltip_text = Loc.t("palette.%s.name" % id)
		var color := Color.html(String(palette.get("color", "#9a9aa8")))
		button.add_theme_stylebox_override("normal", UIKit.stylebox(color, 8))
		button.add_theme_stylebox_override("pressed", UIKit.stylebox(color, 8, 4, UIKit.ACCENT))
		button.pressed.connect(func(): Progression.set_selected_palette(id))
		swatches.add_child(button)
	body.add_child(UIKit.row(Loc.t("party.profile_color"), swatches))
