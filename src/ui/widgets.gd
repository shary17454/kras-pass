class_name Widgets
extends RefCounted
## Composite UI pieces shared by several screens: character cards, mini-game
## cards, stat blocks, standings rows. Keeping them here is what stops the
## character grid on the gallery, the quick-play picker and the local lobby from
## drifting into three different-looking things.


static func character_card(c: CharacterData, unlocked: bool, selected: bool = false) -> Control:
	var col := UIKit.adapt(c.color)
	var card := UIKit.panel(
		Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.95) if unlocked else Color(0.12, 0.13, 0.2, 0.9),
		18)
	if selected:
		card.add_theme_stylebox_override("panel", UIKit.stylebox(
			Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 1.0), 18, 4, UIKit.ACCENT))
	card.custom_minimum_size = Vector2(300, 360)
	var v := UIKit.vbox(6)
	card.add_child(v)

	if unlocked:
		v.add_child(character_portrait(c))
	else:
		v.add_child(UIKit.centered("?", 54, UIKit.dim_color(), true))

	v.add_child(UIKit.centered(c.display_name() if unlocked else Loc.t("common.locked"), UIKit.SIZE_BODY, UIKit.text_color(), true))
	v.add_child(UIKit.centered(Loc.t(c.realm_key) if unlocked else "", UIKit.SIZE_TINY, UIKit.dim_color()))
	if unlocked:
		v.add_child(UIKit.centered(Loc.t("archetype." + c.archetype), UIKit.SIZE_TINY, UIKit.ACCENT))
		var perk := UIKit.centered(Loc.t("perk." + c.perk), UIKit.SIZE_TINY, UIKit.dim_color())
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(perk)
		v.add_child(stat_block(c))
	else:
		var hint := UIKit.centered(Progression.unlock_hint(c.unlock), UIKit.SIZE_TINY, UIKit.ACCENT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(250, 0)
		v.add_child(hint)
	return card


static func character_portrait(character: CharacterData) -> Control:
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(160, 160)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() == "headless":
		return image
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	image.add_child(viewport)
	var model := MeshFactory.character_body(character)
	model.position.y = -0.62
	model.rotation.y = PI + 0.5
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.35, 3.0)
	camera.fov = 42.0
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, 38, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	image.texture = viewport.get_texture()
	return image


static func palette_card(id: String, unlocked: bool, selected: bool) -> Control:
	var swatch_color := UIKit.adapt(Color.html(String(Registry.palette(id).get("color", "#9a9aa8"))))
	var card := UIKit.panel(
		Color(swatch_color.r * 0.3, swatch_color.g * 0.3, swatch_color.b * 0.3, 0.95) if unlocked
			else Color(0.12, 0.13, 0.2, 0.9), 18)
	if selected:
		card.add_theme_stylebox_override("panel", UIKit.stylebox(
			Color(swatch_color.r * 0.4, swatch_color.g * 0.4, swatch_color.b * 0.4, 1.0), 18, 4, UIKit.ACCENT))
	card.custom_minimum_size = Vector2(220, 220)
	var v := UIKit.vbox(6)
	card.add_child(v)
	var dot := UIKit.panel(swatch_color if unlocked else Color(0.25, 0.25, 0.3), 12)
	dot.custom_minimum_size = Vector2(0, 88)
	v.add_child(dot)
	v.add_child(UIKit.centered(
		Loc.t("palette.%s.name" % id) if unlocked else Loc.t("common.locked"),
		UIKit.SIZE_BODY, UIKit.text_color(), true))
	if not unlocked:
		var hint := UIKit.centered(Progression.unlock_hint(Registry.palette(id).get("unlock", {})),
			UIKit.SIZE_TINY, UIKit.ACCENT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	return card


static func stat_block(c: CharacterData) -> Control:
	var v := UIKit.vbox(3)
	var rows := [
		["char.stat.speed", c.speed], ["char.stat.accel", c.accel],
		["char.stat.weight", c.weight], ["char.stat.jump", c.jump],
		["char.stat.power", c.power], ["char.stat.control", c.control],
	]
	for r in rows:
		var h := UIKit.hbox(8)
		var l := UIKit.label(Loc.t(String(r[0])), UIKit.SIZE_TINY, UIKit.dim_color())
		l.custom_minimum_size = Vector2(118, 0)
		h.add_child(l)
		h.add_child(UIKit.stat_bar(float(r[1]), c.accent, 145.0))
		v.add_child(h)
	return v


static func minigame_card(m: MiniGameDef, unlocked: bool) -> Control:
	var card := UIKit.panel(UIKit.PANEL if unlocked else Color(0.11, 0.12, 0.18), 16)
	card.custom_minimum_size = Vector2(360, 185)
	var v := UIKit.vbox(4)
	card.add_child(v)
	var top := UIKit.hbox(10)
	top.add_child(UIKit.label(m.icon_glyph, UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	var name := UIKit.label(m.display_name(), UIKit.SIZE_BODY, UIKit.text_color(), true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	v.add_child(top)
	var desc := UIKit.label(Loc.t(m.desc_key) if unlocked else Progression.unlock_hint(m.unlock),
		UIKit.SIZE_TINY, UIKit.dim_color())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(320, 62)
	v.add_child(desc)
	if unlocked:
		var entry := Stats.game_entry(m.id)
		v.add_child(UIKit.label("%s %s · %s %s" % [
			Loc.t("stats.plays"), entry.get("plays", 0),
			Loc.t("stats.best"), entry.get("best", 0),
		], UIKit.SIZE_TINY, UIKit.dim_color()))
	return card


static func standings_row(rank: int, name: String, color: Color, value: String, highlight: bool) -> Control:
	var card := UIKit.panel(UIKit.PANEL_HI if highlight else UIKit.PANEL, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(16)
	card.add_child(h)
	var place := UIKit.label(Loc.t("ordinal.%d" % mini(rank, 4)), UIKit.SIZE_BODY, UIKit.ACCENT, true)
	place.custom_minimum_size = Vector2(110, 0)
	h.add_child(place)
	var dot := UIKit.panel(UIKit.adapt(color), 8)
	dot.custom_minimum_size = Vector2(24, 24)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var label := UIKit.label(name, UIKit.SIZE_BODY)
	label.name = "PlayerName"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(label)
	h.add_child(UIKit.label(value, UIKit.SIZE_BODY, UIKit.text_color(), true))
	return card


static func progress_row(label_text: String, value: String, fraction: float, color: Color) -> Control:
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(12)
	var l := UIKit.label(label_text, UIKit.SIZE_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UIKit.label(value, UIKit.SIZE_SMALL, UIKit.ACCENT, true))
	v.add_child(h)
	v.add_child(UIKit.stat_bar(fraction, color, 520.0))
	return v


## Grid that scrolls, used for the character and mini-game galleries.
static func scroll_grid(columns: int) -> Array:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = columns
	var fit := func(): grid.columns = 1 if grid.get_viewport_rect().size.x < grid.get_viewport_rect().size.y else columns
	grid.tree_entered.connect(func():
		grid.get_viewport().size_changed.connect(fit)
		fit.call())
	grid.tree_exiting.connect(func(): grid.get_viewport().size_changed.disconnect(fit))
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return [scroll, grid]


## Wraps any control in a focusable button so a gamepad can select a card.
static func selectable(content: Control, on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = content.custom_minimum_size
	b.add_theme_stylebox_override("focus", UIKit.stylebox(Color(1, 1, 1, 0.10), 18, 4, UIKit.ACCENT))
	b.add_theme_stylebox_override("hover", UIKit.stylebox(Color(1, 1, 1, 0.05), 18))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(content)
	b.pressed.connect(on_press)
	b.focus_entered.connect(func(): AudioManager.play_ui("ui_move"))
	return b
