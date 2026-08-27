class_name UIKit
extends RefCounted
## Shared UI construction. Every screen is built in code from these helpers.
##
## Two things this centralises that are easy to get wrong in a bilingual game:
##
## 1. **Fonts.** Godot's bundled font has no Arabic glyphs. Using `SystemFont`
##    with OS fallback gives correct Arabic shaping and bidi on macOS, Windows,
##    iOS and Android without shipping — or licensing — a font file.
## 2. **Direction.** `Loc.is_rtl()` flips container layout, text alignment and
##    the meaning of "back", so the Arabic build is genuinely right-to-left
##    rather than left-to-right text that happens to be Arabic.

const BG := Color("#0d1020")
const PANEL := Color("#1a1f3a")
const PANEL_HI := Color("#252c52")
const ACCENT := Color("#ffb347")
const ACCENT_2 := Color("#57e0c0")
const TEXT := Color("#f2f4ff")
const TEXT_DIM := Color("#9aa2c8")
const DANGER := Color("#ff5f6d")
const OK := Color("#6bd67d")

const SIZE_TITLE := 74
const SIZE_HEADING := 40
const SIZE_BODY := 26
const SIZE_SMALL := 20
const SIZE_TINY := 16

static var _theme: Theme
static var _font: Font
static var _font_bold: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SF Pro Display", "Helvetica Neue", "Segoe UI", "Noto Sans", "Arial"])
		f.allow_system_fallback = true
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font = f
	return _font


static func font_bold() -> Font:
	if _font_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SF Pro Display", "Helvetica Neue", "Segoe UI", "Noto Sans", "Arial"])
		f.font_weight = 700
		f.allow_system_fallback = true
		_font_bold = f
	return _font_bold


static func scale() -> float:
	return float(UserSettings.get_value("text_scale"))


static func text_color() -> Color:
	return Color.WHITE if bool(UserSettings.get_value("high_contrast")) else TEXT


static func dim_color() -> Color:
	return Color(0.85, 0.87, 0.95) if bool(UserSettings.get_value("high_contrast")) else TEXT_DIM


## Colour-vision adjustment. Applied to every player/team colour so the four
## competitors stay distinguishable for the ~8% of players who need it.
static func adapt(c: Color) -> Color:
	match int(UserSettings.get_value("colorblind_mode")):
		1:  # protanopia — reds collapse; push them to orange/yellow
			return Color(c.r * 0.55 + c.g * 0.45, c.g * 0.85 + c.r * 0.15, c.b, c.a)
		2:  # deuteranopia — greens collapse; separate on blue
			return Color(c.r * 0.9 + c.g * 0.1, c.g * 0.6 + c.b * 0.4, c.b * 0.95 + c.g * 0.15, c.a)
		3:  # tritanopia — blues collapse; separate on red
			return Color(c.r * 0.95 + c.b * 0.2, c.g * 0.8, c.b * 0.55 + c.g * 0.45, c.a)
	return c


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = int(SIZE_BODY * scale())
	_theme = t
	return t


static func invalidate_theme() -> void:
	_theme = null


# --- builders --------------------------------------------------------------

static func label(text: String, size: int = SIZE_BODY, color: Color = Color.TRANSPARENT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold() if bold else font())
	l.add_theme_font_size_override("font_size", int(size * scale()))
	l.add_theme_color_override("font_color", text_color() if color == Color.TRANSPARENT else color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	l.text_direction = Control.TEXT_DIRECTION_RTL if Loc.is_rtl() else Control.TEXT_DIRECTION_LTR
	return l


static func title(text: String) -> Label:
	var l := label(text, SIZE_TITLE, ACCENT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func heading(text: String) -> Label:
	return label(text, SIZE_HEADING, text_color(), true)


static func centered(text: String, size: int = SIZE_BODY, color: Color = Color.TRANSPARENT, bold := false) -> Label:
	var l := label(text, size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func stylebox(color: Color, radius: int = 14, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border > 0:
		sb.border_width_left = border
		sb.border_width_right = border
		sb.border_width_top = border
		sb.border_width_bottom = border
		sb.border_color = border_color
	return sb


static func panel(color: Color = PANEL, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(color, radius))
	return p


static func button(text: String, size: int = SIZE_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", int(size * scale()))
	b.add_theme_color_override("font_color", text_color())
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", BG)
	b.add_theme_color_override("font_pressed_color", BG)
	b.add_theme_stylebox_override("normal", stylebox(PANEL, 14, 2, PANEL_HI))
	b.add_theme_stylebox_override("hover", stylebox(PANEL_HI, 14, 2, ACCENT))
	b.add_theme_stylebox_override("focus", stylebox(ACCENT, 14, 2, Color.WHITE))
	b.add_theme_stylebox_override("pressed", stylebox(ACCENT.darkened(0.15), 14))
	b.add_theme_stylebox_override("disabled", stylebox(PANEL.darkened(0.3), 14))
	b.custom_minimum_size = Vector2(0, 58 * scale())
	b.focus_mode = Control.FOCUS_ALL
	# Menu audio is wired here so no screen has to remember it.
	b.focus_entered.connect(func(): AudioManager.play_ui("ui_move"))
	b.pressed.connect(func(): AudioManager.play_ui("ui_select"))
	b.mouse_entered.connect(func():
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	return b


static func icon_button(glyph: String, tooltip: String) -> Button:
	var b := button(glyph, SIZE_HEADING)
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(72 * scale(), 72 * scale())
	return b


static func slider(value: float, lo: float, hi: float, step: float = 0.05) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(320 * scale(), 40)
	s.focus_mode = Control.FOCUS_ALL
	return s


static func option(items: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(String(it))
	o.selected = clampi(selected, 0, maxi(0, items.size() - 1))
	o.add_theme_font_override("font", font())
	o.add_theme_font_size_override("font_size", int(SIZE_BODY * scale()))
	o.focus_mode = Control.FOCUS_ALL
	o.custom_minimum_size = Vector2(280 * scale(), 52)
	return o


static func checkbox(text: String, pressed: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = pressed
	c.add_theme_font_override("font", font())
	c.add_theme_font_size_override("font_size", int(SIZE_BODY * scale()))
	c.add_theme_color_override("font_color", text_color())
	c.focus_mode = Control.FOCUS_ALL
	return c


## Labelled row that mirrors correctly in Arabic.
static func row(label_text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l := label(label_text)
	l.custom_minimum_size = Vector2(340 * scale(), 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	if Loc.is_rtl():
		h.add_child(control)
		h.add_child(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		h.add_child(l)
		h.add_child(control)
	return h


static func stat_bar(value: float, color: Color, width: float = 220.0) -> Control:
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", stylebox(Color(1, 1, 1, 0.10), 8))
	back.custom_minimum_size = Vector2(width * scale(), 16)
	var fill := PanelContainer.new()
	fill.add_theme_stylebox_override("panel", stylebox(adapt(color), 8))
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fill.custom_minimum_size = Vector2(maxf(6.0, width * scale() * clampf(value, 0.0, 1.0)), 16)
	back.add_child(fill)
	return back


static func spacer(height: float = 16.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## Full-screen root with the game's background. Every screen starts with this.
static func screen_root() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	return root


## Full-screen margin that respects the device safe area, so a landscape
## iPhone never puts a button under the notch or the home indicator.
static func margin(child: Control, m: int = 56) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var insets := Platform.ui_margin(m)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, int(insets[side]))
	mc.add_child(child)
	return mc


static func vbox(separation: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## Fade + rise entrance used by every screen so navigation feels continuous.
static func animate_in(node: Control, delay: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	node.modulate.a = 1.0
	var start := node.position
	node.position = start + Vector2(0, 26)
	var tw := node.create_tween()
	tw.tween_property(node, "position", start, 0.32).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func pulse(node: Control) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.09)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14)
