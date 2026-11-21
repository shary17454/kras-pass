class_name SettingToggle
extends CheckButton
## Icon-only switch. The caller owns its value, tooltip and settings persistence.

const CONTROL_SIZE := Vector2(96.0, 72.0)
const TRACK_SIZE := Vector2(80.0, 44.0)
const KNOB_RADIUS := 17.0

var _held := false


func _init() -> void:
	custom_minimum_size = CONTROL_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Preserve BaseButton input and signals, but replace every native switch icon.
	var blank_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank_image.fill(Color.TRANSPARENT)
	var blank_icon := ImageTexture.create_from_image(blank_image)
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
		"checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored",
		"unchecked_disabled_mirrored"]:
		add_theme_icon_override(icon_name, blank_icon)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_constant_override("h_separation", 0)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	toggled.connect(_on_toggled)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _ready() -> void:
	var appearance := get_node_or_null("/root/UITheme")
	if appearance != null and appearance.has_signal("appearance_changed"):
		appearance.connect("appearance_changed", _on_appearance_changed)


func _get_minimum_size() -> Vector2:
	return CONTROL_SIZE


func _draw() -> void:
	# Geometry stays intrinsic even if an external layout assigns extra space.
	var track_rect := Rect2((size - TRACK_SIZE) * 0.5, TRACK_SIZE)
	var track_color: Color = UIKit.ACCENT_2 if button_pressed else UIKit.PANEL_HI
	var edge_color: Color = UIKit.ACCENT_2 if button_pressed else UIKit.TEXT_DIM
	var knob_color: Color = UIKit.PANEL if button_pressed else UIKit.TEXT
	var border_width := 2
	if disabled:
		track_color = track_color.lerp(UIKit.PANEL, 0.6)
		edge_color = UIKit.TEXT_DIM
		knob_color = UIKit.TEXT.lerp(UIKit.PANEL, 0.25)
	elif _held:
		track_color = track_color.lerp(UIKit.TEXT, 0.18)
		edge_color = UIKit.TEXT
		border_width = 3
	elif is_hovered():
		track_color = track_color.lerp(UIKit.TEXT, 0.1)
		edge_color = UIKit.TEXT
		border_width = 3

	if has_focus():
		var focus_rect := Rect2((size - CONTROL_SIZE) * 0.5 + Vector2(2, 2),
			CONTROL_SIZE - Vector2(4, 4))
		var focus_color: Color = UIKit.TEXT_DIM if disabled else UIKit.ACCENT
		var focus_style := _rounded_style(Color.TRANSPARENT, focus_color, 3, 16)
		focus_style.draw(get_canvas_item(), focus_rect)

	var track_style := _rounded_style(track_color, edge_color, border_width, 22)
	track_style.draw(get_canvas_item(), track_rect)
	var knob_x := track_rect.end.x - 22.0 if button_pressed else track_rect.position.x + 22.0
	var knob_center := Vector2(knob_x, track_rect.get_center().y)
	var radius := KNOB_RADIUS - (1.0 if _held and not disabled else 0.0)
	draw_circle(knob_center, radius, knob_color, true, -1.0, true)
	draw_arc(knob_center, radius, 0.0, TAU, 48, edge_color, 1.0, true)


func _rounded_style(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _on_button_down() -> void:
	_held = true
	queue_redraw()


func _on_button_up() -> void:
	_held = false
	queue_redraw()


func _on_toggled(_pressed: bool) -> void:
	queue_redraw()


func _on_appearance_changed(_dark: bool) -> void:
	queue_redraw()
