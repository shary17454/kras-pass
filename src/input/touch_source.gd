class_name TouchSource
extends Control
## On-screen controls that produce the ordinary `InputFrame`.
##
## This is the fourth input source, after pads, keyboards and AI brains, and it
## is deliberately the same shape as the others: it writes movement and button
## bits into `InputRouter` and nothing downstream can tell a thumb from a stick.
## There is no touch-related code in any of the 21 mini-games.
##
## Multitouch is handled centrally rather than by per-widget `_gui_input`: one
## handler owns the index→widget map, which is the only way a player can hold
## the stick, an action button and a second button at once without widgets
## stealing each other's fingers. Mouse events are handled too, so the layout
## can be exercised on a desktop without a device.

const STICK_RADIUS := 110.0
const STICK_DEAD := 0.14
const BUTTON_RADIUS := 74.0
const EDGE_MARGIN := 54.0

var slot := 0
var profile: ControlProfile.Kind = ControlProfile.Kind.MOVEMENT_ACTION
var buttons: Array[String] = []

var _scale := 1.0
var _opacity := 0.5
var _left_handed := false
var _haptics := true

## touch index -> {"kind": "move"|"aim"|"button"|"steer"|"screen", "id": …}
var _owners := {}
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _bits := 0
var _steer := 0.0
var _throttle := 0.0
var _pressed_buttons := {}
var _move_origin := Vector2.ZERO
var _aim_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _aim_knob := Vector2.ZERO
var _inset_left := 0.0
var _inset_right := 0.0
var _inset_bottom := 0.0
var _font: Font
var touch_index := 0
var touch_count := 1
var editing := false
var _editing_id := ""
var _edit_point := Vector2.ZERO


func setup(player_slot: int, def: MiniGameDef, index_in_group := 0, group_size := 1) -> void:
	slot = player_slot
	touch_index = index_in_group
	touch_count = clampi(group_size, 1, 4)
	profile = def.control_profile
	buttons = ControlProfile.buttons_for(profile, def.control_hints)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIKit.font_bold()
	_read_settings()
	UserSettings.changed.connect(_on_setting_changed)
	# A Control parented to a CanvasLayer is not sized by anchors — it stays at
	# zero and silently draws nothing. Size it from the viewport explicitly and
	# follow rotations and window resizes.
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	set_process_input(true)


func _fit_to_viewport() -> void:
	_owners.clear()
	_pressed_buttons.clear()
	_move = Vector2.ZERO
	_aim = Vector2.ZERO
	_bits = 0
	_steer = 0.0
	_throttle = 0.0
	position = Vector2.ZERO
	size = get_viewport_rect().size
	# Keep the thumb targets clear of the notch and the home indicator.
	var insets := Platform.safe_insets()
	_inset_left = insets.x
	_inset_right = insets.z
	_inset_bottom = insets.w
	if touch_count > 1:
		var region := party_region(size, touch_index, touch_count)
		position = region.position
		size = region.size
		_inset_left = 0.0
		_inset_right = 0.0
		_inset_bottom = 0.0
		_scale = minf(float(UserSettings.get_value("touch_scale")), minf(size.x / 700.0, size.y / 550.0))
	InputRouter.push_virtual(slot, Vector2.ZERO, Vector2.ZERO, 0)
	queue_redraw()


static func party_region(viewport_size: Vector2, index: int, count: int) -> Rect2:
	var columns := mini(2, count) if viewport_size.x < viewport_size.y else count
	var rows := ceili(float(count) / columns)
	var height := viewport_size.y * (0.21 if rows > 1 else 0.30)
	var width := viewport_size.x / columns
	return Rect2(Vector2((index % columns) * width, viewport_size.y - rows * height + int(index / columns) * height), Vector2(width, height))


func _read_settings() -> void:
	_scale = float(UserSettings.get_value("touch_scale"))
	if touch_count > 1 and size.x > 0 and size.y > 0:
		_scale = minf(_scale, minf(size.x / 700.0, size.y / 550.0))
	_opacity = float(UserSettings.get_value("touch_opacity"))
	_left_handed = bool(UserSettings.get_value("touch_left_handed"))
	_haptics = bool(UserSettings.get_value("vibration"))


func _on_setting_changed(key: String, _value) -> void:
	if key.begins_with("touch") or key == "vibration" or key == "*":
		_read_settings()
		queue_redraw()


## True when the on-screen controls should exist at all.
static func should_show() -> bool:
	match String(UserSettings.get_value("touch_controls")):
		"on":
			return true
		"off":
			return false
	# "auto": show on a touchscreen device, hide everywhere else.
	return DisplayServer.is_touchscreen_available()


# --- geometry --------------------------------------------------------------

func _left_edge() -> float:
	return (EDGE_MARGIN if touch_count == 1 else 12.0) + _inset_left


func _right_edge() -> float:
	return size.x - (EDGE_MARGIN if touch_count == 1 else 12.0) - _inset_right


func _bottom_edge() -> float:
	return size.y - (EDGE_MARGIN if touch_count == 1 else 12.0) - _inset_bottom


func _move_on_right() -> bool:
	if profile == ControlProfile.Kind.KEEPER:
		return _keeper_side("touch_keeper_move_side") == "right"
	# ATV controls default to right-hand steering; the setting mirrors both sides.
	return not _left_handed if profile == ControlProfile.Kind.ATV else _left_handed


func _keeper_side(setting: String) -> String:
	var side := String(UserSettings.get_value(setting))
	return side if side in ["left", "right"] else "right"


func _keeper_button_on_right(action: String) -> bool:
	var setting := "touch_keeper_return_side" if action == "attack" else "touch_keeper_dash_side"
	return _keeper_side(setting) == "right"


func _stick_centre() -> Vector2:
	return _layout_position("move", _default_stick_centre(), STICK_RADIUS * _scale * ControlProfile.stick_scale(profile))


func _default_stick_centre() -> Vector2:
	var r := STICK_RADIUS * _scale * ControlProfile.stick_scale(profile)
	var x := _left_edge() + r
	if _move_on_right():
		x = _right_edge() - r
	return Vector2(x, _bottom_edge() - r)


func _aim_centre() -> Vector2:
	return _layout_position("aim", _default_aim_centre(), STICK_RADIUS * _scale)


func _default_aim_centre() -> Vector2:
	var r := STICK_RADIUS * _scale
	var x := _right_edge() - r
	if _left_handed:
		x = _left_edge() + r
	return Vector2(x, _bottom_edge() - r)


## Buttons fan out in an arc away from the stick hand.
func _button_centre(index: int) -> Vector2:
	return _layout_position("button_" + buttons[index], _default_button_centre(index), BUTTON_RADIUS * _scale)


func _default_button_centre(index: int) -> Vector2:
	var r := BUTTON_RADIUS * _scale
	if touch_count > 1:
		if ControlProfile.shows_aim_stick(profile) or ControlProfile.shows_steering(profile):
			return Vector2(size.x * 0.5 + (index - (buttons.size() - 1) * 0.5) * r * 2.3, 40.0 + r)
		var x := _left_edge() + r if _move_on_right() else _right_edge() - r
		if buttons.size() > 2:
			x += (index % 2) * r * 2.2 * (1.0 if _move_on_right() else -1.0)
			return Vector2(x, _bottom_edge() - r - int(index / 2) * r * 2.2)
		return Vector2(x, _bottom_edge() - r - index * r * 2.2)
	if profile == ControlProfile.Kind.ATV:
		var x := _left_edge() + r if _move_on_right() else _right_edge() - r
		return Vector2(x, _bottom_edge() - r - index * r * 2.3)
	if profile == ControlProfile.Kind.KEEPER:
		var action := buttons[index]
		var on_right := _keeper_button_on_right(action)
		var rank := 0
		for earlier in index:
			if _keeper_button_on_right(buttons[earlier]) == on_right:
				rank += 1
		# The movement stick owns the lowest spot on its side. An action assigned
		# there moves above it, keeping every legal layout usable with two thumbs.
		if on_right == _move_on_right():
			rank += 1
		var x := _right_edge() - r if on_right else _left_edge() + r
		# A keeper stick is wider than an action button; three radii leaves an
		# actual thumb gap when an action shares the steering side.
		return Vector2(x, _bottom_edge() - r - rank * r * 3.2)
	if size.x < size.y and buttons.size() > 2:
		var x := _right_edge() - r - float(1 - index % 2) * r * 2.2
		if _left_handed:
			x = _left_edge() + r + float(1 - index % 2) * r * 2.2
		return Vector2(x, _bottom_edge() - r - float(index / 2) * r * 2.2)
	var base_x := _right_edge() - r * 1.2
	var dir := -1.0
	if _left_handed:
		base_x = _left_edge() + r * 1.2
		dir = 1.0
	var base := Vector2(base_x, _bottom_edge() - r * 1.2)
	var angles := [0.0, -55.0, -110.0, -165.0]
	var a := deg_to_rad(float(angles[index % angles.size()]))
	var spread := r * 2.35
	return base + Vector2(cos(a) * spread * dir, sin(a) * spread)


func _steer_rects() -> Array:
	var w := size.x * 0.22
	var h := size.y * 0.34
	var y := _bottom_edge() - h
	var left := Rect2(_left_edge(), y, w, h)
	var right := Rect2(_left_edge() + w + 18.0, y, w, h)
	var throttle := Rect2(_right_edge() - w, y, w, h)
	if _left_handed:
		throttle = Rect2(_left_edge(), y, w, h)
		left = Rect2(_right_edge() - w * 2.0 - 18.0, y, w, h)
		right = Rect2(_right_edge() - w, y, w, h)
	return [left, right, throttle]


func _button_hit(pos: Vector2) -> int:
	var r := BUTTON_RADIUS * _scale
	for i in buttons.size():
		if pos.distance_to(_button_centre(i)) <= r * 1.15:
			return i
	return -1


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if editing:
		_edit_input(event)
		return
	if event is InputEventScreenTouch:
		_handle_press(event.index, event.position - global_position, event.pressed)
		if _owners.has(event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(-1, event.position - global_position, event.pressed)
	elif event is InputEventMouseMotion and _owners.has(-1):
		_handle_drag(-1, event.position - global_position)


func _handle_press(index: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		_release(index)
		return
	if not Rect2(Vector2.ZERO, size).has_point(pos):
		return
	var full := ControlProfile.full_screen_tap(profile)
	if full != 0:
		_owners[index] = {"kind": "screen", "bit": full}
		_bits |= full
		_pulse()
		queue_redraw()
		return

	var button := _button_hit(pos)
	if button >= 0:
		_owners[index] = {"kind": "button", "id": button}
		_press_button(button, true)
		return

	if ControlProfile.shows_steering(profile):
		var rects := _steer_rects()
		for i in 3:
			if (rects[i] as Rect2).has_point(pos):
				_owners[index] = {"kind": "steer", "id": i}
				_apply_steer(i, true)
				queue_redraw()
				return
		return

	# Sticks claim their half of the screen, not just their drawn circle: a
	# thumb that lands slightly off should still grab the stick.
	var mid := size.x * 0.5
	var on_stick_side := (pos.x < mid) != _move_on_right()
	var layouts: Dictionary = UserSettings.get_value("touch_positions")
	if touch_count == 1 and layouts.has(layout_key()):
		on_stick_side = not ControlProfile.shows_aim_stick(profile) or \
			pos.distance_squared_to(_stick_centre()) <= pos.distance_squared_to(_aim_centre())
	if ControlProfile.shows_move_stick(profile) and on_stick_side:
		if _owners_has("move"):
			return
		_owners[index] = {"kind": "move"}
		_move_origin = pos
		_move_knob = pos
		queue_redraw()
		return
	if ControlProfile.shows_aim_stick(profile) and not on_stick_side:
		if _owners_has("aim"):
			return
		_owners[index] = {"kind": "aim"}
		_aim_origin = pos
		_aim_knob = pos
		queue_redraw()


func _handle_drag(index: int, pos: Vector2) -> void:
	var owner = _owners.get(index)
	if owner == null:
		return
	match String(owner["kind"]):
		"move":
			_move_knob = pos
			_move = _stick_vector(_move_origin, pos)
			queue_redraw()
		"aim":
			_aim_knob = pos
			_aim = _stick_vector(_aim_origin, pos)
			queue_redraw()
		"button":
			# Sliding off a button releases it, which is what a player expects.
			if _button_hit(pos) != int(owner["id"]):
				_owners.erase(index)
				_press_button(int(owner["id"]), false)


func _release(index: int) -> void:
	var owner = _owners.get(index)
	if owner == null:
		return
	_owners.erase(index)
	match String(owner["kind"]):
		"move":
			_move = Vector2.ZERO
			_move_knob = _move_origin
		"aim":
			_aim = Vector2.ZERO
			_aim_knob = _aim_origin
		"button":
			_press_button(int(owner["id"]), false)
		"steer":
			_apply_steer(int(owner["id"]), false)
		"screen":
			_bits &= ~int(owner["bit"])
	queue_redraw()


func _stick_vector(origin: Vector2, pos: Vector2) -> Vector2:
	var r := STICK_RADIUS * _scale * ControlProfile.stick_scale(profile)
	var v := (pos - origin) / r
	if v.length() < clampf(float(UserSettings.get_value("touch_dead_zone")), 0.05, 0.4):
		return Vector2.ZERO
	return v.limit_length(1.0)


func _press_button(index: int, down: bool) -> void:
	if index < 0 or index >= buttons.size():
		return
	if not down:
		for owner in _owners.values():
			if owner["kind"] == "button" and int(owner["id"]) == index:
				return
	var bit: int = ControlProfile.BUTTON_BITS.get(buttons[index], 0)
	if down:
		_bits |= bit
		_pressed_buttons[index] = true
		_pulse()
	else:
		_bits &= ~bit
		_pressed_buttons.erase(index)
	queue_redraw()


func _apply_steer(which: int, down: bool) -> void:
	match which:
		0: _steer = -1.0 if down else 0.0
		1: _steer = 1.0 if down else 0.0
		2: _throttle = 1.0 if down else 0.0


func _pulse() -> void:
	if _haptics:
		Input.vibrate_handheld(18)


func _physics_process(_delta: float) -> void:
	if editing:
		return
	var move := _move
	if ControlProfile.shows_steering(profile):
		# Steering games read x as turn and y as throttle; forward is -y, the
		# same convention a keyboard "up" produces.
		move = Vector2(_steer, -_throttle)
	InputRouter.push_virtual(slot, move, _aim, _bits)


func layout_key() -> String:
	return "%d:%s" % [profile, "portrait" if size.x < size.y else "landscape"]


func _layout_position(id: String, fallback: Vector2, radius: float) -> Vector2:
	if touch_count > 1:
		return fallback
	if editing and _editing_id == id:
		return _edit_point
	var layouts = UserSettings.get_value("touch_positions")
	var layout = layouts.get(layout_key(), {}) if layouts is Dictionary else {}
	var point = layout.get(id, []) if layout is Dictionary else []
	if not point is Array or point.size() != 2:
		return fallback
	return _clamp_control(Vector2(float(point[0]), float(point[1])) * size, radius)


func _clamp_control(point: Vector2, radius: float) -> Vector2:
	return Vector2(clampf(point.x, radius + 16, maxf(radius + 16, size.x - radius - 16)),
		clampf(point.y, maxf(radius + 16, size.y * 0.3), maxf(radius + 16, size.y - radius - 24)))


func editable_controls() -> Dictionary:
	var controls := {}
	if ControlProfile.shows_move_stick(profile):
		controls["move"] = {"point": _stick_centre(), "radius": STICK_RADIUS * _scale * ControlProfile.stick_scale(profile)}
	if ControlProfile.shows_aim_stick(profile):
		controls["aim"] = {"point": _aim_centre(), "radius": STICK_RADIUS * _scale}
	for i in buttons.size():
		controls["button_" + buttons[i]] = {"point": _button_centre(i), "radius": BUTTON_RADIUS * _scale}
	return controls


func save_control_position(id: String, point: Vector2) -> bool:
	var controls := editable_controls()
	if not controls.has(id) or size.x <= 0 or size.y <= 0:
		return false
	var radius := float(controls[id]["radius"])
	var clamped := _clamp_control(point, radius)
	for other in controls:
		if other != id and clamped.distance_to(controls[other]["point"]) < radius + float(controls[other]["radius"]) + 12.0:
			return false
	var layouts: Dictionary = UserSettings.get_value("touch_positions").duplicate(true)
	var layout: Dictionary = layouts.get(layout_key(), {})
	layout[id] = [clamped.x / size.x, clamped.y / size.y]
	layouts[layout_key()] = layout
	UserSettings.set_value("touch_positions", layouts)
	return true


func _edit_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not pressed
		point = event.position - global_position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not pressed
		point = event.position - global_position
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		point = event.position - global_position
	else:
		return
	if pressed:
		for id in editable_controls():
			var target: Dictionary = editable_controls()[id]
			if point.distance_to(target["point"]) <= float(target["radius"]):
				_editing_id = id
				_edit_point = point
				break
	if _editing_id.is_empty():
		return
	var radius := float(editable_controls()[_editing_id]["radius"])
	_edit_point = _clamp_control(point, radius)
	if released:
		var id := _editing_id
		_editing_id = ""
		save_control_position(id, _edit_point)
	get_viewport().set_input_as_handled()
	queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	var a := clampf(_opacity, 0.05, 1.0)
	var ink := Color(1, 1, 1, a)
	var fill := Color(1, 1, 1, a * 0.14)
	if touch_count > 1:
		draw_line(Vector2.ZERO, Vector2(size.x, 0), ink, 2.0)
		_label("P%d %s" % [slot + 1, PlayerConfig.SYMBOLS[slot]], Vector2(size.x * 0.5, 24), Color.WHITE, 24)

	if ControlProfile.full_screen_tap(profile) != 0:
		var active := _bits != 0
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, a * (0.16 if active else 0.05)))
		_label(Loc.t("touch.tap_anywhere"), size * 0.5, ink, 42, size.x - 24)
		return

	if ControlProfile.shows_steering(profile):
		var rects := _steer_rects()
		var glyphs := ["◀", "▶", "▲"]
		var states := [_steer < -0.5, _steer > 0.5, _throttle > 0.5]
		for i in 3:
			var r: Rect2 = rects[i]
			draw_rect(r, Color(1, 1, 1, a * (0.22 if states[i] else 0.10)), true)
			draw_rect(r, ink, false, 3.0)
			_label(glyphs[i], r.get_center(), ink, mini(52, int(r.size.y * 0.65)), r.size.x - 12)
	elif ControlProfile.shows_move_stick(profile):
		_draw_stick(_stick_centre() if not _owners_has("move") else _move_origin,
			_move_knob if _owners_has("move") else _stick_centre(), ink, fill,
			STICK_RADIUS * _scale * ControlProfile.stick_scale(profile))
		if profile == ControlProfile.Kind.ATV:
			var origin := _move_origin if _owners_has("move") else _stick_centre()
			var radius := STICK_RADIUS * _scale
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var glyph := "▲" if direction == Vector2.UP else "▼" if direction == Vector2.DOWN else "◀" if direction == Vector2.LEFT else "▶"
				_label(glyph, origin + direction * radius * 0.77, Color.WHITE, 25)
		if profile == ControlProfile.Kind.KEEPER:
			var origin := _move_origin if _owners_has("move") else _stick_centre()
			for direction in [-1.0, 1.0]:
				_label("◀" if direction < 0 else "▶", origin + Vector2(direction * STICK_RADIUS * _scale * 0.77, 0), Color.WHITE, 25)

	if ControlProfile.shows_aim_stick(profile):
		_draw_stick(_aim_centre() if not _owners_has("aim") else _aim_origin,
			_aim_knob if _owners_has("aim") else _aim_centre(), ink, fill, STICK_RADIUS * _scale)

	# A button has to say what it does. White outlines with an abstract glyph —
	# "»" for dash, "✦" for attack — told a player nothing about either, and at
	# 12%% fill they were barely on the screen at all. Each verb now gets its own
	# colour, a filled body, and its name written underneath in the player's
	# language, which is the same word the pre-round card already uses.
	var br := BUTTON_RADIUS * _scale
	for i in buttons.size():
		var c := _button_centre(i)
		var down: bool = _pressed_buttons.has(i)
		var tint := _button_color(buttons[i])
		var body := Color(tint.r * 0.45, tint.g * 0.45, tint.b * 0.45, maxf(0.78, a))
		var edge := Color(1, 1, 1, a * 0.95)
		draw_circle(c, br, body)
		draw_arc(c, br, 0.0, TAU, 36, edge, 4.0, true)
		_label(_glyph(buttons[i]), c - Vector2(0, br * 0.22), Color.WHITE, mini(40, int(br * 0.85)))
		_label(_action_name(buttons[i]), c + Vector2(0, br * 0.43), Color.WHITE, mini(34, int(br * 0.65)), br * 1.65)
		if down:
			draw_arc(c, br - 6.0, 0.0, TAU, 36, tint, 5.0, true)


func _draw_stick(origin: Vector2, knob: Vector2, ink: Color, fill: Color, r: float) -> void:
	draw_circle(origin, r, fill)
	draw_arc(origin, r, 0.0, TAU, 40, ink, 3.0, true)
	var clamped := origin + (knob - origin).limit_length(r)
	draw_circle(clamped, r * 0.42, Color(ink.r, ink.g, ink.b, ink.a * 0.55))
	draw_arc(clamped, r * 0.42, 0.0, TAU, 24, ink, 2.5, true)


func _owners_has(kind: String) -> bool:
	for o in _owners.values():
		if String(o["kind"]) == kind:
			return true
	return false


func _label(text: String, centre: Vector2, color: Color, size_px: int, max_width := -1.0) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	while max_width > 0 and w > max_width and size_px > 8:
		size_px -= 1
		w = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(_font, centre + Vector2(-w * 0.5, size_px * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


## One colour per verb, so a glance at the corner is enough to know which
## button is which without reading anything.
func _button_color(action: String) -> Color:
	match action:
		"attack", "shoot": return Color(0.92, 0.35, 0.30)
		"dash", "boost": return Color(0.25, 0.62, 0.95)
		"jump": return Color(0.36, 0.78, 0.45)
		"ability": return Color(0.78, 0.45, 0.92)
		"action": return Color(0.95, 0.70, 0.25)
	return Color(0.6, 0.65, 0.8)


## The same word the rules card shows for this verb.
func _action_name(action: String) -> String:
	if profile == ControlProfile.Kind.KEEPER and action == "attack":
		return Loc.t("controls.return_ball")
	if profile in [ControlProfile.Kind.STEERING, ControlProfile.Kind.ATV] and action in ["attack", "shoot"]:
		return Loc.t("controls.weapon")
	var key := "controls.%s" % action
	return Loc.t(key) if Loc.has(key) else ""


func _glyph(action: String) -> String:
	if action == "shoot" or (profile in [ControlProfile.Kind.STEERING, ControlProfile.Kind.ATV] and action == "attack"):
		return "⌖"
	match action:
		"jump": return "▲"
		"attack": return "✊"
		"action": return "◉"
		"dash", "boost": return "➤"
		"ability": return "★"
	return "●"
