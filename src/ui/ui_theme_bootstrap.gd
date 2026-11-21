extends Node
## Imported fonts are unavailable while a fresh editor checkout is importing.
## Populate the dependency-free project theme before any runtime UI is built.

signal appearance_changed(dark: bool)

var _applied_palette: Dictionary = {}
var _refresh_pending := false

func _enter_tree() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var bundled_theme := load("res://assets/fonts/ui_theme.tres") as Theme
	if project_theme == null or bundled_theme == null or bundled_theme.default_font == null:
		push_error("Cannot initialize the bundled project font")
		get_tree().quit(1)
		return
	project_theme.default_font = bundled_theme.default_font
	project_theme.default_font_size = bundled_theme.default_font_size


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UserSettings.changed.connect(_on_setting_changed)
	if DisplayServer.get_name() != "headless":
		DisplayServer.set_system_theme_change_callback(refresh)
	refresh.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		refresh()


func _on_setting_changed(key: String, _value) -> void:
	if key in ["appearance", "high_contrast", "*"] and not _refresh_pending:
		_refresh_pending = true
		refresh.call_deferred()


func resolve_dark(mode: String, supported: bool, system_dark: bool) -> bool:
	if mode == "light":
		return false
	if mode == "dark":
		return true
	return system_dark if supported else true


func refresh() -> void:
	_refresh_pending = false
	var dark := resolve_dark(String(UserSettings.get_value("appearance")),
		DisplayServer.is_dark_mode_supported(), DisplayServer.is_dark_mode())
	apply_appearance(dark)


func apply_appearance(dark: bool) -> void:
	var previous := _applied_palette if not _applied_palette.is_empty() else UIKit.palette()
	UIKit.set_dark_mode(dark)
	var current := UIKit.palette()
	if current == _applied_palette:
		return
	_applied_palette = current
	_configure_defaults(ThemeDB.get_project_theme())
	_configure_defaults(UIKit.theme())
	_apply_tree(get_tree().root, previous)
	appearance_changed.emit(dark)


func _configure_defaults(theme: Theme) -> void:
	# Emit one completed palette update, not hundreds of intermediate relayouts.
	var blocked := theme.is_blocking_signals()
	theme.set_block_signals(true)
	for type in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "LinkButton",
		"LineEdit", "TextEdit", "PopupMenu", "RichTextLabel", "Tree", "ItemList", "TabBar", "SpinBox"]:
		for key in ["font_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color",
			"font_focus_color", "font_selected_color", "default_color"]:
			theme.set_color(key, type, UIKit.text_color())
		theme.set_color("font_disabled_color", type, UIKit.dim_color())
		theme.set_color("font_placeholder_color", type, UIKit.dim_color())
		theme.set_color("caret_color", type, UIKit.TEXT)
		theme.set_color("selection_color", type, Color(UIKit.ACCENT_2, 0.25))
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit", "TextEdit"]:
		for state in ["normal", "read_only", "disabled"]:
			theme.set_stylebox(state, type, UIKit.stylebox(UIKit.PANEL, 8, 1, UIKit.GLASS_EDGE))
			if type == "OptionButton":
				theme.set_stylebox(state + "_mirrored", type, theme.get_stylebox(state, type))
		for state in ["hover", "pressed", "hover_pressed", "focus"]:
			theme.set_stylebox(state, type, UIKit.stylebox(UIKit.PANEL_HI, 8, 2, UIKit.ACCENT_2))
			if type == "OptionButton":
				theme.set_stylebox(state + "_mirrored", type, theme.get_stylebox(state, type))
	for type in ["PopupMenu", "PopupPanel", "Panel", "PanelContainer", "AcceptDialog", "Window", "TooltipPanel"]:
		theme.set_stylebox("panel", type, UIKit.stylebox(UIKit.PANEL, 8, 1, UIKit.GLASS_EDGE))
	theme.set_color("font_color", "TooltipLabel", UIKit.text_color())
	theme.set_color("font_outline_color", "TooltipLabel", Color.TRANSPARENT)
	theme.set_stylebox("hover", "PopupMenu", UIKit.stylebox(UIKit.PANEL_HI, 4))
	theme.set_color("title_color", "Window", UIKit.text_color())
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	for type in ["Tree", "ItemList"]:
		for state in ["selected", "selected_focus"]:
			theme.set_stylebox(state, type, UIKit.stylebox(UIKit.PANEL_HI, 4, 1, UIKit.ACCENT_2))
	theme.set_stylebox("slider", "HSlider", UIKit.stylebox(UIKit.PANEL_HI, 4))
	theme.set_stylebox("grabber_area", "HSlider", UIKit.stylebox(UIKit.ACCENT_2, 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", UIKit.stylebox(UIKit.ACCENT_2, 4))
	theme.set_block_signals(blocked)
	if not blocked:
		theme.emit_changed()


func _mapped(color: Color, previous: Dictionary, font_color := false) -> Color:
	var keys: Array = ["text", "dim", "base_text", "base_dim", "accent", "accent_2", "danger", "ok"] if font_color else previous.keys()
	for key in keys:
		var before: Color = previous[key]
		if Vector3(color.r, color.g, color.b).is_equal_approx(Vector3(before.r, before.g, before.b)):
			var after: Color = _applied_palette[key]
			return Color(after, color.a)
	return color


func _apply_style(style: StyleBoxFlat, previous: Dictionary) -> void:
	if style.get_meta("appearance_fixed", false):
		return
	var glass: Dictionary = style.get_meta("appearance_glass", {})
	if not glass.is_empty():
		var original: Color = glass["color"]
		var seed := Color(_applied_palette.get(glass["role"], original), original.a)
		style.bg_color = UIKit.liquid_glass_color(seed, bool(glass["lifted"]))
		style.border_color = UIKit.GLASS_EDGE.lightened(0.14) if glass["lifted"] else UIKit.GLASS_EDGE
	else:
		var role := String(style.get_meta("appearance_bg", ""))
		style.bg_color = Color(_applied_palette[role], style.bg_color.a) if role != "" else _mapped(style.bg_color, previous)
		role = String(style.get_meta("appearance_border", ""))
		style.border_color = Color(_applied_palette[role], style.border_color.a) if role != "" else _mapped(style.border_color, previous)
	if style.has_meta("appearance_tint"):
		var tint: Color = style.get_meta("appearance_tint")
		style.bg_color = tint if UIKit.dark_mode else tint.lerp(Color(1, 1, 1, tint.a), 0.88)
	if style.shadow_size > 0:
		style.shadow_color = UIKit.GLASS_SHADOW


func _apply_tree(node: Node, previous: Dictionary) -> void:
	if node is Control:
		for property in node.get_property_list():
			var key := String(property["name"])
			if key.begins_with("theme_override_colors/"):
				var value = node.get(key)
				if value is Color:
					var mapped := _mapped(value, previous, true)
					if mapped != value:
						node.set(key, mapped)
			elif key.begins_with("theme_override_styles/"):
				var style = node.get(key)
				if style is StyleBoxFlat:
					_apply_style(style, previous)
		if node is ColorRect and node.get_meta("appearance_background", false) and node.color.a > 0:
			node.color = UIKit.BG
		if node is Label and node.get_meta("appearance_label", false):
			node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
			var white_ink: bool = node.get_theme_color("font_color") == Color.WHITE
			node.add_theme_constant_override("outline_size", 6 if UIKit.dark_mode else 2 if white_ink else 0)
		node.queue_redraw()
	for child in node.get_children(true):
		_apply_tree(child, previous)
