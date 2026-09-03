class_name MatchHUD
extends CanvasLayer
## In-match interface: player chips, clock, countdown, rules card, banners.
##
## The HUD is a pure listener. It reads `MatchContext` and reacts to `EventBus`;
## it never calls into a mini-game and no mini-game holds a reference to it.
## Updates are throttled to `performance.hud_update_hz` because rebuilding four
## score chips at 60 Hz is pure waste on a handheld.

var ctx: MatchContext
var controller: MiniGameController

var _chips: Array = []
var _timer_label: Label
var _banner_label: Label
var _round_label: Label
var _centre_label: Label
var _rules_card: Control
var _hint_label: Label
var _toast_box: VBoxContainer
## Width of the per-player charge meter, in unscaled pixels.
const METER_WIDTH := 118.0

var _accum := 0.0
var _period := 1.0 / 12.0
var _low_time := false


func setup(context: MatchContext, ctrl: MiniGameController) -> void:
	ctx = context
	controller = ctrl
	layer = 10
	_period = 1.0 / maxf(1.0, Balance.num("tuning", "performance.hud_update_hz", 12.0))
	_build()
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.player_eliminated.connect(_on_eliminated)
	EventBus.notification_requested.connect(show_toast)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	add_child(root)

	# --- clock -------------------------------------------------------------
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -220
	top.offset_right = 220
	top.offset_top = 18
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	_timer_label = UIKit.centered("0:00", 72, UIKit.TEXT, true)
	top.add_child(_timer_label)
	_round_label = UIKit.centered("", UIKit.SIZE_SMALL, UIKit.dim_color())
	top.add_child(_round_label)
	_banner_label = UIKit.centered("", UIKit.SIZE_BODY, UIKit.ACCENT_2, true)
	top.add_child(_banner_label)

	# --- player chips ------------------------------------------------------
	# The spec puts the four players along the top with the clock between them,
	# and it is the right call for a 3D party game: the bottom third of the
	# screen is where bodies fight and where the touch controls live, so a chip
	# strip down there covers the action and sits under the player's thumbs.
	# One container with an expanding gap in the middle means the clock can
	# never overlap a chip at any window width.
	var chips := HBoxContainer.new()
	chips.set_anchors_preset(Control.PRESET_TOP_WIDE)
	chips.offset_top = 14
	chips.offset_bottom = 156
	chips.offset_left = 26
	chips.offset_right = -26
	chips.add_theme_constant_override("separation", 14)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chips)
	var players: Array = ctx.config.players
	var half := int(ceil(players.size() / 2.0))
	for i in players.size():
		if i == half:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(430, 0)
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.add_child(gap)
		chips.add_child(_make_chip(players[i]))
	if players.size() <= half:
		var tail := Control.new()
		tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(tail)

	# --- centre announcements ---------------------------------------------
	_centre_label = UIKit.centered("", 120, UIKit.ACCENT, true)
	_centre_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre_label.modulate.a = 0.0
	root.add_child(_centre_label)

	# --- rules card --------------------------------------------------------
	_rules_card = _make_rules_card()
	root.add_child(_rules_card)
	_rules_card.visible = false

	# --- control hint strip -----------------------------------------------
	_hint_label = UIKit.centered(_control_hint_text(), UIKit.SIZE_SMALL, UIKit.dim_color())
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.offset_top = -58
	_hint_label.offset_bottom = -22
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_label)

	# --- toasts ------------------------------------------------------------
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT if not Loc.is_rtl() else Control.PRESET_TOP_LEFT)
	_toast_box.offset_left = 24 if Loc.is_rtl() else -500
	_toast_box.offset_right = 500 if Loc.is_rtl() else -24
	_toast_box.offset_top = 140
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)


func _make_chip(p: PlayerConfig) -> Control:
	var col := UIKit.adapt(p.color())
	var card := UIKit.panel(Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.86), 16)
	# Menu padding is generous on purpose; a match chip cannot afford it. Four
	# chips at menu padding measured 356 px each, which put the outermost one
	# 56 px off the left of a 1920-wide screen.
	_tighten(card, 10, 8)
	card.custom_minimum_size = Vector2(214, 0)
	# Shrink, don't fill: a filling chip eats the gap the clock sits in.
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var portrait := _make_portrait(p, col)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var name_label := UIKit.label(p.display_name(), UIKit.SIZE_TINY, UIKit.text_color(), true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(104, 0)
	box.add_child(name_label)

	var value := UIKit.label("0", 40, Color.WHITE, true)
	value.name = "Value"
	value.clip_text = true
	box.add_child(value)

	# The per-player meter the spec asks for. Where a game has no dash the bar
	# would be a permanently full decoration, so it is hidden instead.
	var meter := UIKit.stat_bar(1.0, col, METER_WIDTH)
	meter.name = "Meter"
	_tighten(meter, 0, 0)
	meter.visible = controller != null and controller.allows_dash()
	box.add_child(meter)

	var effects := HBoxContainer.new()
	effects.name = "Effects"
	effects.add_theme_constant_override("separation", 6)
	box.add_child(effects)

	_chips.append({"root": card, "value": value, "effects": effects, "slot": p.slot,
		"color": col, "meter": meter, "meter_fill": meter.get_child(0), "charge": -1.0})
	return card


## Replace a UIKit panel's padding with something a HUD can live with, reusing
## the same stylebox recipe so the corner radius and colour still match.
func _tighten(panel: PanelContainer, h: int, v: int) -> void:
	var current := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if current == null:
		return
	var sb := current.duplicate() as StyleBoxFlat
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	panel.add_theme_stylebox_override("panel", sb)


## A real portrait, rendered from the same body the player controls. The project
## ships no image assets by rule, so the chip renders the character mesh into a
## 96x96 viewport once and shows that. Headless — tests, the balance simulator —
## gets the flat colour swatch instead, because there is no renderer to ask.
func _make_portrait(p: PlayerConfig, col: Color) -> Control:
	var frame := UIKit.panel(Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.95), 12)
	_tighten(frame, 3, 3)
	frame.custom_minimum_size = Vector2(64, 64)
	var character := p.character()
	if DisplayServer.get_name() == "headless" or character == null:
		var swatch := UIKit.panel(col, 10)
		_tighten(swatch, 0, 0)
		swatch.custom_minimum_size = Vector2(58, 58)
		frame.add_child(swatch)
		return frame
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = true
	vp.disable_3d = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var body := MeshFactory.character_body(character)
	body.position = Vector3(0, -0.62, 0)
	body.rotation.y = 0.5
	vp.add_child(body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.5, 2.05)
	cam.fov = 42.0
	vp.add_child(cam)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-32, 38, 0)
	lamp.light_energy = 1.4
	vp.add_child(lamp)
	var view := TextureRect.new()
	view.custom_minimum_size = Vector2(58, 58)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vp)
	frame.add_child(view)
	view.texture = vp.get_texture()
	return frame


func _make_rules_card() -> Control:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := UIKit.panel(Color(UIKit.PANEL.r, UIKit.PANEL.g, UIKit.PANEL.b, 0.94), 24)
	card.custom_minimum_size = Vector2(1080, 0)
	var v := UIKit.vbox(14)
	card.add_child(v)
	var d := ctx.definition
	v.add_child(UIKit.centered(d.display_name(), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	var rules := UIKit.centered(Loc.t(d.rules_key), UIKit.SIZE_BODY)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(1000, 0)
	v.add_child(rules)
	v.add_child(UIKit.centered(_control_hint_text(), UIKit.SIZE_SMALL, UIKit.ACCENT_2))
	if ctx.config.subtitle_key != "":
		v.add_child(UIKit.centered(Loc.t(ctx.config.subtitle_key), UIKit.SIZE_SMALL, UIKit.dim_color()))
	wrapper.add_child(card)
	return wrapper


func _control_hint_text() -> String:
	var parts: Array[String] = []
	for hint in ctx.definition.control_hints:
		var key := "controls.%s" % hint
		if Loc.has(key):
			parts.append(Loc.t(key))
	return "  ·  ".join(parts)


# --- public API used by MatchScene -----------------------------------------

func set_time(remaining: float, hurry_threshold: float) -> void:
	_timer_label.text = Loc.time_mmss(remaining)
	var low := remaining <= hurry_threshold and remaining > 0.0
	if low != _low_time:
		_low_time = low
		_timer_label.add_theme_color_override("font_color", UIKit.DANGER if low else UIKit.TEXT)
	if low and not bool(UserSettings.get_value("reduce_effects")):
		var k := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06
		_timer_label.scale = Vector2(k, k)
		_timer_label.pivot_offset = _timer_label.size * 0.5


func set_round(index: int, total: int) -> void:
	_round_label.text = Loc.t("hud.round_of", {"n": index + 1, "total": total}) if total > 1 else ""


func set_banner(text: String) -> void:
	_banner_label.text = text


func show_rules(visible_: bool) -> void:
	_rules_card.visible = visible_
	if visible_:
		UIKit.animate_in(_rules_card)


func show_hints(visible_: bool) -> void:
	_hint_label.visible = visible_


func announce(text: String, color: Color = UIKit.ACCENT, hold := 0.75) -> void:
	_centre_label.text = text
	_centre_label.add_theme_color_override("font_color", color)
	if DisplayServer.get_name() == "headless":
		return
	_centre_label.modulate.a = 1.0
	_centre_label.scale = Vector2(1.5, 1.5)
	_centre_label.pivot_offset = _centre_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_centre_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_centre_label, "modulate:a", 0.0, 0.25)


func show_toast(text: String, icon: String = "") -> void:
	var card := UIKit.panel(Color(UIKit.PANEL_HI.r, UIKit.PANEL_HI.g, UIKit.PANEL_HI.b, 0.92), 12)
	var l := UIKit.label(("%s  %s" % [icon, text]).strip_edges(), UIKit.SIZE_SMALL)
	card.add_child(l)
	_toast_box.add_child(card)
	if DisplayServer.get_name() == "headless":
		card.queue_free()
		return
	UIKit.animate_in(card)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)


func tick(delta: float) -> void:
	_accum += delta
	if _accum < _period:
		return
	_accum = 0.0
	_refresh_chips()
	var banner := controller.hud_banner() if controller != null else ""
	if banner != _banner_label.text and banner != "":
		_banner_label.text = banner


func _refresh_chips() -> void:
	for chip in _chips:
		var slot: int = chip["slot"]
		chip["value"].text = controller.hud_value(slot) if controller != null else str(ctx.scores[slot])
		var alive: bool = ctx.is_alive(slot)
		chip["root"].modulate = Color(1, 1, 1, 1.0 if alive else 0.4)
		_refresh_meter(chip, slot)
		_refresh_effects(chip, slot)


func _refresh_meter(chip: Dictionary, slot: int) -> void:
	var meter: Control = chip["meter"]
	if not meter.visible:
		return
	var f := ctx.fighter(slot)
	if f == null or not is_instance_valid(f):
		return
	var value: float = clampf(f.charge, 0.0, 1.0)
	# Only resize on a visible change: this runs for four chips at the HUD
	# refresh rate and a full-width relayout per frame is pure waste.
	if absf(value - float(chip["charge"])) < 0.02:
		return
	chip["charge"] = value
	var fill := chip["meter_fill"] as Control
	if fill != null:
		fill.custom_minimum_size.x = maxf(6.0, METER_WIDTH * UIKit.scale() * value)


func _refresh_effects(chip: Dictionary, slot: int) -> void:
	var box: HBoxContainer = chip["effects"]
	var effects: Array = ctx.powerups.active_effects_for(slot) if ctx.powerups != null else []
	if box.get_child_count() == effects.size():
		var i := 0
		for e in effects:
			var lbl := box.get_child(i) as Label
			if lbl != null:
				lbl.text = e["glyph"]
			i += 1
		return
	for c in box.get_children():
		c.queue_free()
	for e in effects:
		box.add_child(UIKit.label(String(e["glyph"]), UIKit.SIZE_SMALL, UIKit.adapt(e["color"]), true))


func _on_score_changed(slot: int, _value: int) -> void:
	for chip in _chips:
		if chip["slot"] == slot:
			UIKit.pulse(chip["root"])
			return


func _on_eliminated(slot: int, _place: int) -> void:
	for chip in _chips:
		if chip["slot"] == slot:
			chip["root"].modulate = Color(1, 1, 1, 0.4)
			return
