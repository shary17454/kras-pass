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

	_timer_label = UIKit.centered("0:00", 60, UIKit.TEXT, true)
	top.add_child(_timer_label)
	_round_label = UIKit.centered("", UIKit.SIZE_SMALL, UIKit.dim_color())
	top.add_child(_round_label)
	_banner_label = UIKit.centered("", UIKit.SIZE_BODY, UIKit.ACCENT_2, true)
	top.add_child(_banner_label)

	# --- player chips ------------------------------------------------------
	var chips := HBoxContainer.new()
	chips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	chips.offset_top = -118
	chips.offset_bottom = -24
	chips.offset_left = 40
	chips.offset_right = -40
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 18)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chips)
	for p in ctx.config.players:
		chips.add_child(_make_chip(p))

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
	_hint_label.offset_top = -140
	_hint_label.offset_bottom = -118
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_label)

	# --- toasts ------------------------------------------------------------
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT if not Loc.is_rtl() else Control.PRESET_TOP_LEFT)
	_toast_box.offset_left = 24 if Loc.is_rtl() else -420
	_toast_box.offset_right = 420 if Loc.is_rtl() else -24
	_toast_box.offset_top = 120
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)


func _make_chip(p: PlayerConfig) -> Control:
	var col := UIKit.adapt(p.color())
	var card := UIKit.panel(Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.86), 16)
	card.custom_minimum_size = Vector2(240, 84)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	var dot := UIKit.panel(col, 8)
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(dot)
	var name_label := UIKit.label(p.display_name(), UIKit.SIZE_SMALL, UIKit.text_color(), true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var value := UIKit.label("0", UIKit.SIZE_HEADING, Color.WHITE, true)
	value.name = "Value"
	box.add_child(value)

	var effects := HBoxContainer.new()
	effects.name = "Effects"
	effects.add_theme_constant_override("separation", 6)
	box.add_child(effects)

	_chips.append({"root": card, "value": value, "effects": effects, "slot": p.slot, "color": col})
	return card


func _make_rules_card() -> Control:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := UIKit.panel(Color(UIKit.PANEL.r, UIKit.PANEL.g, UIKit.PANEL.b, 0.94), 24)
	card.custom_minimum_size = Vector2(900, 0)
	var v := UIKit.vbox(14)
	card.add_child(v)
	var d := ctx.definition
	v.add_child(UIKit.centered(d.display_name(), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	var rules := UIKit.centered(Loc.t(d.rules_key), UIKit.SIZE_BODY)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(840, 0)
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
		_refresh_effects(chip, slot)


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
