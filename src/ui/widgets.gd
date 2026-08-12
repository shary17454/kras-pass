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
	card.custom_minimum_size = Vector2(250, 300)
	var v := UIKit.vbox(6)
	card.add_child(v)

	var swatch := UIKit.panel(col if unlocked else Color(0.25, 0.25, 0.3), 12)
	swatch.custom_minimum_size = Vector2(0, 86)
	var glyph := UIKit.centered("?" if not unlocked else "◆", 46, UIKit.BG, true)
	swatch.add_child(glyph)
	v.add_child(swatch)

	v.add_child(UIKit.centered(c.display_name() if unlocked else Loc.t("common.locked"), UIKit.SIZE_BODY, UIKit.text_color(), true))
	v.add_child(UIKit.centered(Loc.t(c.realm_key) if unlocked else "", UIKit.SIZE_TINY, UIKit.dim_color()))
	if unlocked:
		v.add_child(stat_block(c))
	else:
		var hint := UIKit.centered(Progression.unlock_hint(c.unlock), UIKit.SIZE_TINY, UIKit.ACCENT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(210, 0)
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
		l.custom_minimum_size = Vector2(96, 0)
		h.add_child(l)
		h.add_child(UIKit.stat_bar(float(r[1]), c.accent, 120.0))
		v.add_child(h)
	return v


static func minigame_card(m: MiniGameDef, unlocked: bool) -> Control:
	var card := UIKit.panel(UIKit.PANEL if unlocked else Color(0.11, 0.12, 0.18), 16)
	card.custom_minimum_size = Vector2(300, 150)
	var v := UIKit.vbox(4)
	card.add_child(v)
	var top := UIKit.hbox(10)
	top.add_child(UIKit.label(m.icon_glyph, UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	var name := UIKit.label(m.display_name() if unlocked else Loc.t("common.locked"), UIKit.SIZE_BODY, UIKit.text_color(), true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	v.add_child(top)
	var desc := UIKit.label(Loc.t(m.desc_key) if unlocked else Progression.unlock_hint(m.unlock),
		UIKit.SIZE_TINY, UIKit.dim_color())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(270, 44)
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
	var h := UIKit.hbox(16)
	card.add_child(h)
	var place := UIKit.label(Loc.t("ordinal.%d" % mini(rank, 4)), UIKit.SIZE_BODY, UIKit.ACCENT, true)
	place.custom_minimum_size = Vector2(90, 0)
	h.add_child(place)
	var dot := UIKit.panel(UIKit.adapt(color), 8)
	dot.custom_minimum_size = Vector2(20, 20)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var label := UIKit.label(name, UIKit.SIZE_BODY)
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
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
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
